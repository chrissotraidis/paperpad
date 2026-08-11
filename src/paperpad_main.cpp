// PaperPad native runner.
//
// Adapted from Paper Mario ReCut's main.cpp (MIT) cross-platform core:
// N64Recomp game entry, SDL window/input/audio, RT64 rendering via
// paper_rt64_context. The Windows launcher UI, texture-replacement tooling,
// and built-in texture pack are intentionally not ported; the Apple shell
// (UIKit) drives the same entry points on iOS.

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#define SDL_MAIN_HANDLED
#include "SDL.h"
#include "SDL_syswm.h"

#include "librecomp/game.hpp"
#include "librecomp/overlays.hpp"
#include "librecomp/rsp.hpp"
#include "builtin_texture_pack.h"
#include "paper_rt64_context.h"
#include "ultramodern/ultra64.h"
#include "ultramodern/ultramodern.hpp"

#include "paperpad_input.h"

#if defined(__APPLE__) && TARGET_OS_IPHONE
extern "C" void paperpad_touch_snapshot(uint16_t* buttons, float* x, float* y);
extern "C" void paperpad_touch_attach(void* ui_window);
extern "C" void paperpad_fix_metal_layer_scale(void* ui_window, void* metal_layer);
#endif
#include "paperpad_paths.h"

namespace paper_mario {
    void register_overlays();
}

extern "C" void recomp_entrypoint(uint8_t* rdram, recomp_context* ctx);
extern "C" recomp_func_t* get_function(int32_t addr);
gpr get_entrypoint_address();

namespace {
    constexpr uint64_t paper_mario_us_xxh3 = 0x1A478F060D5194CFULL;
    constexpr int32_t paper_mario_step_game_loop_vram = 0x80026740;
    recomp_func_t* original_step_game_loop = nullptr;

    constexpr uint16_t A_BUTTON = 0x8000;
    constexpr uint16_t B_BUTTON = 0x4000;
    constexpr uint16_t Z_BUTTON = 0x2000;
    constexpr uint16_t START_BUTTON = 0x1000;
    constexpr uint16_t U_JPAD = 0x0800;
    constexpr uint16_t D_JPAD = 0x0400;
    constexpr uint16_t L_JPAD = 0x0200;
    constexpr uint16_t R_JPAD = 0x0100;
    constexpr uint16_t L_TRIG = 0x0020;
    constexpr uint16_t R_TRIG = 0x0010;
    constexpr uint16_t U_CBUTTONS = 0x0008;
    constexpr uint16_t D_CBUTTONS = 0x0004;
    constexpr uint16_t L_CBUTTONS = 0x0002;
    constexpr uint16_t R_CBUTTONS = 0x0001;

    SDL_Window* window = nullptr;
    SDL_GameController* controller = nullptr;
#if defined(__APPLE__) && TARGET_OS_IPHONE
    // iOS: native handles retained for periodic window/layer diagnostics.
    void* ios_ui_window = nullptr;
    void* ios_metal_layer = nullptr;
#endif
    SDL_AudioDeviceID audio_device = 0;
    SDL_AudioStream* audio_stream = nullptr;
    uint32_t sample_rate = 48000;
    uint32_t output_sample_rate = 48000;
    constexpr uint32_t input_channels = 2;
    constexpr uint32_t output_channels = 2;
    constexpr uint32_t bytes_per_input_frame = input_channels * sizeof(float);

    struct AudioTelemetry {
        std::chrono::steady_clock::time_point next_report{};
        uint64_t callbacks = 0;
        uint64_t input_frames = 0;
        uint64_t output_frames = 0;
        uint64_t peak_queue_us = 0;
        uint64_t over_100ms_callbacks = 0;
        uint32_t peak_input = 0;
        uint64_t boundary_delta_sum_ppm = 0;
        uint64_t boundary_count = 0;
        uint32_t peak_boundary_delta_ppm = 0;
        uint32_t peak_within_delta_ppm = 0;
        uint64_t conversion_errors = 0;
        uint64_t queue_errors = 0;
    } audio_telemetry;
    std::array<float, output_channels> previous_output_frame{};
    bool has_previous_output_frame = false;

    void report_audio_telemetry(uint64_t current_queue_us) {
        const auto now = std::chrono::steady_clock::now();
        if (audio_telemetry.next_report.time_since_epoch().count() == 0) {
            audio_telemetry.next_report = now + std::chrono::seconds(2);
            return;
        }
        if (now < audio_telemetry.next_report) return;

        std::fprintf(stderr,
            "[audio] input_hz=%u output_hz=%u callbacks=%llu input_frames=%llu "
            "output_frames=%llu queue_us=%llu peak_queue_us=%llu over_100ms=%llu "
            "peak_input=%u boundary_avg_ppm=%llu boundary_peak_ppm=%u "
            "within_peak_ppm=%u conversion_errors=%llu queue_errors=%llu\n",
            sample_rate,
            output_sample_rate,
            static_cast<unsigned long long>(audio_telemetry.callbacks),
            static_cast<unsigned long long>(audio_telemetry.input_frames),
            static_cast<unsigned long long>(audio_telemetry.output_frames),
            static_cast<unsigned long long>(current_queue_us),
            static_cast<unsigned long long>(audio_telemetry.peak_queue_us),
            static_cast<unsigned long long>(audio_telemetry.over_100ms_callbacks),
            audio_telemetry.peak_input,
            static_cast<unsigned long long>(audio_telemetry.boundary_count == 0
                ? 0
                : audio_telemetry.boundary_delta_sum_ppm / audio_telemetry.boundary_count),
            audio_telemetry.peak_boundary_delta_ppm,
            audio_telemetry.peak_within_delta_ppm,
            static_cast<unsigned long long>(audio_telemetry.conversion_errors),
            static_cast<unsigned long long>(audio_telemetry.queue_errors));

        audio_telemetry = {};
        audio_telemetry.next_report = now + std::chrono::seconds(2);
    }

    // Touch overlay state written by the Apple shell.
    std::atomic<uint16_t> touch_buttons{0};
    std::atomic<float> touch_stick_x{0.0f};
    std::atomic<float> touch_stick_y{0.0f};
    std::atomic<float> audio_volume{1.0f};
    std::atomic<bool> graphics_settings_applied{false};

    enum class InputAction : int {
        N64A,
        N64B,
        Start,
        Z,
        L,
        R,
        CUp,
        CDown,
        CLeft,
        CRight,
        DPadUp,
        DPadDown,
        DPadLeft,
        DPadRight,
        StickUp,
        StickDown,
        StickLeft,
        StickRight,
        Count
    };

    constexpr int input_action_count = static_cast<int>(InputAction::Count);

    struct InputActionDescriptor {
        InputAction action;
        const char* label;
        uint16_t button;
        int axis_x;
        int axis_y;
    };

    constexpr std::array<InputActionDescriptor, input_action_count> input_actions{ {
        { InputAction::N64A, "A Button", A_BUTTON, 0, 0 },
        { InputAction::N64B, "B Button", B_BUTTON, 0, 0 },
        { InputAction::Start, "Start", START_BUTTON, 0, 0 },
        { InputAction::Z, "Z Trigger", Z_BUTTON, 0, 0 },
        { InputAction::L, "L Trigger", L_TRIG, 0, 0 },
        { InputAction::R, "R Trigger", R_TRIG, 0, 0 },
        { InputAction::CUp, "C Up", U_CBUTTONS, 0, 0 },
        { InputAction::CDown, "C Down", D_CBUTTONS, 0, 0 },
        { InputAction::CLeft, "C Left", L_CBUTTONS, 0, 0 },
        { InputAction::CRight, "C Right", R_CBUTTONS, 0, 0 },
        { InputAction::DPadUp, "D-Pad Up", U_JPAD, 0, 0 },
        { InputAction::DPadDown, "D-Pad Down", D_JPAD, 0, 0 },
        { InputAction::DPadLeft, "D-Pad Left", L_JPAD, 0, 0 },
        { InputAction::DPadRight, "D-Pad Right", R_JPAD, 0, 0 },
        { InputAction::StickUp, "Stick Up", 0, 0, 1 },
        { InputAction::StickDown, "Stick Down", 0, 0, -1 },
        { InputAction::StickLeft, "Stick Left", 0, -1, 0 },
        { InputAction::StickRight, "Stick Right", 0, 1, 0 }
    } };

    enum class GamepadBindingKind {
        Button,
        AxisPositive,
        AxisNegative
    };

    struct GamepadBinding {
        GamepadBindingKind kind = GamepadBindingKind::Button;
        int code = SDL_CONTROLLER_BUTTON_INVALID;
    };

    struct AppInputSettings {
        int preferred_controller_index = 0;
        std::array<SDL_Scancode, input_action_count> keyboard_bindings{};
        std::array<GamepadBinding, input_action_count> gamepad_bindings{};
    };

    AppInputSettings make_default_input_settings() {
        AppInputSettings settings{};
        settings.keyboard_bindings = {
            SDL_SCANCODE_Z,
            SDL_SCANCODE_X,
            SDL_SCANCODE_RETURN,
            SDL_SCANCODE_LSHIFT,
            SDL_SCANCODE_Q,
            SDL_SCANCODE_E,
            SDL_SCANCODE_I,
            SDL_SCANCODE_K,
            SDL_SCANCODE_J,
            SDL_SCANCODE_L,
            SDL_SCANCODE_W,
            SDL_SCANCODE_S,
            SDL_SCANCODE_A,
            SDL_SCANCODE_D,
            SDL_SCANCODE_UP,
            SDL_SCANCODE_DOWN,
            SDL_SCANCODE_LEFT,
            SDL_SCANCODE_RIGHT
        };
        settings.gamepad_bindings = {
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_A },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_X },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_START },
            GamepadBinding{ GamepadBindingKind::AxisPositive, SDL_CONTROLLER_AXIS_TRIGGERLEFT },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_LEFTSHOULDER },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER },
            GamepadBinding{ GamepadBindingKind::AxisNegative, SDL_CONTROLLER_AXIS_RIGHTY },
            GamepadBinding{ GamepadBindingKind::AxisPositive, SDL_CONTROLLER_AXIS_RIGHTY },
            GamepadBinding{ GamepadBindingKind::AxisNegative, SDL_CONTROLLER_AXIS_RIGHTX },
            GamepadBinding{ GamepadBindingKind::AxisPositive, SDL_CONTROLLER_AXIS_RIGHTX },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_DPAD_UP },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_DPAD_DOWN },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_DPAD_LEFT },
            GamepadBinding{ GamepadBindingKind::Button, SDL_CONTROLLER_BUTTON_DPAD_RIGHT },
            GamepadBinding{ GamepadBindingKind::AxisNegative, SDL_CONTROLLER_AXIS_LEFTY },
            GamepadBinding{ GamepadBindingKind::AxisPositive, SDL_CONTROLLER_AXIS_LEFTY },
            GamepadBinding{ GamepadBindingKind::AxisNegative, SDL_CONTROLLER_AXIS_LEFTX },
            GamepadBinding{ GamepadBindingKind::AxisPositive, SDL_CONTROLLER_AXIS_LEFTX }
        };
        return settings;
    }

    std::mutex settings_mutex;
    AppInputSettings input_settings = make_default_input_settings();
    // Preserve very short key taps until the next emulated input poll. SDL's
    // event pump and the game-input callback run on different host threads;
    // polling SDL_GetKeyboardState alone can miss a keydown+keyup pair that
    // occurs between two game frames.
    std::array<std::atomic<uint8_t>, input_action_count> keyboard_tap_latches{};
    int active_controller_device_index = -1;

    std::filesystem::path app_base_path() {
        return std::filesystem::current_path();
    }

    std::filesystem::path app_config_path() {
#if defined(__APPLE__)
        // macOS/iOS: user data belongs in the Application Support directory.
        const char* support_dir = paperpad_apple_application_support_dir();
        std::filesystem::path base = std::filesystem::path(support_dir ? support_dir : "user");
        free(const_cast<char*>(support_dir));
        std::filesystem::create_directories(base);
        return base;
#else
        std::filesystem::path base = app_base_path() / "user";
        std::filesystem::create_directories(base);
        return base;
#endif
    }

    void show_message(const char* msg) {
        std::fprintf(stderr, "%s\n", msg);
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "PaperPad", msg, window);
    }

    void recut_step_game_loop(uint8_t* rdram, recomp_context* ctx) {
        static uint64_t game_loop_count = 0;
        if ((++game_loop_count % 600) == 0) {
            std::fprintf(stderr, "[paperpad] game loop frames: %llu\n",
                (unsigned long long)game_loop_count);
#if defined(__APPLE__) && TARGET_OS_IPHONE
            // Periodic iOS window/layer diagnostics to catch post-rotation state.
            paperpad_log_window_diagnostics(ios_ui_window, ios_metal_layer);
#endif
        }
        if (original_step_game_loop != nullptr) {
            original_step_game_loop(rdram, ctx);
        }
    }

    void install_recut_frame_hooks(uint8_t*, recomp_context*) {
        original_step_game_loop = get_function(paper_mario_step_game_loop_vram);
        std::fprintf(stderr, "[paperpad] step_game_loop hook: %p\n",
            (void*)original_step_game_loop);
        recomp::overlays::add_loaded_function(paper_mario_step_game_loop_vram, recut_step_game_loop);
    }

    bool open_controller_index(int device_index) {
        if (device_index < 0 || device_index >= SDL_NumJoysticks() || !SDL_IsGameController(device_index)) {
            return false;
        }

        SDL_GameController* opened_controller = SDL_GameControllerOpen(device_index);
        if (opened_controller == nullptr) {
            return false;
        }

        if (controller != nullptr) {
            SDL_GameControllerClose(controller);
        }
        controller = opened_controller;
        active_controller_device_index = device_index;
#if defined(__APPLE__) && TARGET_OS_IPHONE
        PaperPad_SetPhysicalControllerConnected(1);
#endif
        std::fprintf(stderr, "[input] controller connected: %s\n",
            SDL_GameControllerName(controller) ?: "unknown");
        return true;
    }

    void open_first_controller() {
        if (controller != nullptr) {
            return;
        }

        const int count = SDL_NumJoysticks();
        int preferred_controller_index = 0;
        {
            std::lock_guard<std::mutex> lock(settings_mutex);
            preferred_controller_index = input_settings.preferred_controller_index;
        }

        if (open_controller_index(preferred_controller_index)) {
            return;
        }

        for (int i = 0; i < count; i++) {
            if (i != preferred_controller_index && open_controller_index(i)) {
                return;
            }
        }
#if defined(__APPLE__) && TARGET_OS_IPHONE
        PaperPad_SetPhysicalControllerConnected(0);
#endif
    }

    ultramodern::gfx_callbacks_t::gfx_data_t create_gfx() {
        SDL_SetHint(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "0");

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER | SDL_INIT_AUDIO) != 0) {
            show_message(SDL_GetError());
            std::exit(EXIT_FAILURE);
        }

        open_first_controller();
        return nullptr;
    }

    ultramodern::renderer::WindowHandle create_window(ultramodern::gfx_callbacks_t::gfx_data_t) {
        uint32_t flags = SDL_WINDOW_RESIZABLE;
#if defined(__APPLE__)
        flags |= SDL_WINDOW_METAL;
#if TARGET_OS_IPHONE
        // iOS owns a full-screen UIWindow. Mark its SDL view borderless so the
        // SDL view controller hides the status bar and gives RT64 the complete
        // drawable before fitting Original (4:3) or Expand.
        flags |= SDL_WINDOW_BORDERLESS;
#endif
#endif

        window = SDL_CreateWindow("PaperPad", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 960, 720, flags);
        if (window == nullptr) {
            show_message(SDL_GetError());
            std::exit(EXIT_FAILURE);
        }
        SDL_ShowWindow(window);

        SDL_SysWMinfo wm_info;
        SDL_VERSION(&wm_info.version);
        SDL_GetWindowWMInfo(window, &wm_info);

#if defined(_WIN32)
        return ultramodern::renderer::WindowHandle{ wm_info.info.win.window, GetCurrentThreadId() };
#elif defined(__linux__) || defined(__ANDROID__)
        return window;
#elif defined(__APPLE__)
#if TARGET_OS_IPHONE
        // iOS: SDL owns the UIWindow; RT64's CocoaWindow maps it.
        std::fprintf(stderr, "[paperpad] window created: ui_window=%p\n",
            wm_info.info.uikit.window);
        void* ios_layer = SDL_Metal_GetLayer(SDL_Metal_CreateView(window));
        ios_ui_window = wm_info.info.uikit.window;
        ios_metal_layer = ios_layer;
        paperpad_fix_metal_layer_scale(wm_info.info.uikit.window, ios_layer);
        paperpad_touch_attach(wm_info.info.uikit.window);
        paperpad_log_window_diagnostics(wm_info.info.uikit.window, ios_layer);
        // One-shot delayed diagnostics (post-swapchain-resize state).
        void* diag_window = wm_info.info.uikit.window;
        void* diag_layer = ios_layer;
        std::thread([diag_window, diag_layer]() {
            for (int i = 0; i < 5; ++i) {
                std::this_thread::sleep_for(std::chrono::seconds(5));
                paperpad_log_window_diagnostics(diag_window, diag_layer);
            }
        }).detach();
        return ultramodern::renderer::WindowHandle{ wm_info.info.uikit.window, ios_layer };
#else
        SDL_MetalView view = SDL_Metal_CreateView(window);
        std::fprintf(stderr, "[paperpad] window created: ns_window=%p layer=%p\n",
            wm_info.info.cocoa.window, SDL_Metal_GetLayer(view));
        return ultramodern::renderer::WindowHandle{ wm_info.info.cocoa.window, SDL_Metal_GetLayer(view) };
#endif
#else
        return window;
#endif
    }

    void update_gfx(void*) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                std::fprintf(stderr, "[paperpad] SDL_QUIT received\n");
                ultramodern::quit();
            }
            else if (event.type == SDL_CONTROLLERDEVICEADDED) {
                open_first_controller();
            }
            else if (event.type == SDL_CONTROLLERDEVICEREMOVED) {
                if (controller != nullptr && event.cdevice.which == SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(controller))) {
                    SDL_GameControllerClose(controller);
                    controller = nullptr;
                    active_controller_device_index = -1;
                    open_first_controller();
                }
            }
            else if (event.type == SDL_KEYDOWN && event.key.repeat == 0) {
                std::lock_guard<std::mutex> lock(settings_mutex);
                for (int i = 0; i < input_action_count; i++) {
                    if (input_settings.keyboard_bindings[i] == event.key.keysym.scancode) {
                        // A few runtime polls can occur inside one rendered
                        // frame. Retain the tap across four polls so the game
                        // sees it in its pressed-button edge calculation.
                        keyboard_tap_latches[i].store(4, std::memory_order_release);
                    }
                }
            }
        }
    }

    void update_audio_stream() {
        if (audio_stream != nullptr) {
            SDL_FreeAudioStream(audio_stream);
            audio_stream = nullptr;
        }

        audio_stream = SDL_NewAudioStream(
            AUDIO_F32,
            input_channels,
            static_cast<int>(sample_rate),
            AUDIO_F32,
            static_cast<Uint8>(output_channels),
            static_cast<int>(output_sample_rate));
        if (audio_stream == nullptr) {
            std::fprintf(stderr, "Error creating SDL audio stream: %s\n", SDL_GetError());
            std::exit(EXIT_FAILURE);
        }
    }

    void reset_audio(uint32_t output_freq) {
        if (audio_device != 0) {
            SDL_CloseAudioDevice(audio_device);
            audio_device = 0;
        }

        SDL_AudioSpec desired{};
        desired.freq = static_cast<int>(output_freq);
        desired.format = AUDIO_F32;
        desired.channels = static_cast<Uint8>(output_channels);
        desired.samples = 256;
        desired.callback = nullptr;

        audio_device = SDL_OpenAudioDevice(nullptr, 0, &desired, nullptr, 0);
        if (audio_device == 0) {
            std::fprintf(stderr, "SDL error opening audio device: %s\n", SDL_GetError());
            std::exit(EXIT_FAILURE);
        }

        SDL_PauseAudioDevice(audio_device, 0);
        output_sample_rate = output_freq;
        update_audio_stream();
    }

    void set_frequency(uint32_t freq) {
        sample_rate = freq == 0 ? 48000 : freq;

        if (audio_device == 0) {
            reset_audio(48000);
            return;
        }

        update_audio_stream();
    }

    void queue_samples(int16_t* audio_data, size_t sample_count) {
        if (audio_device == 0 || sample_count == 0) {
            return;
        }

        static std::vector<float> source_buffer;
        static std::vector<float> converted_buffer;

        source_buffer.resize(sample_count);

        const float output_gain = 0.5f / 32768.0f;
        for (size_t i = 0; i + 1 < sample_count; i += input_channels) {
            audio_telemetry.peak_input = std::max(
                audio_telemetry.peak_input,
                static_cast<uint32_t>(std::max(
                    std::abs(static_cast<int32_t>(audio_data[i + 0])),
                    std::abs(static_cast<int32_t>(audio_data[i + 1])))));
            source_buffer[i + 0] = audio_data[i + 1] * output_gain;
            source_buffer[i + 1] = audio_data[i + 0] * output_gain;
        }

        if (SDL_AudioStreamPut(
                audio_stream,
                source_buffer.data(),
                static_cast<int>(sample_count * sizeof(float))) < 0) {
            audio_telemetry.conversion_errors++;
            std::fprintf(stderr, "Error feeding SDL audio stream: %s\n", SDL_GetError());
            return;
        }

        constexpr uint32_t bytes_per_output_frame = input_channels * sizeof(float);
        uint64_t queued_input_us =
            uint64_t(SDL_GetQueuedAudioSize(audio_device)) /
            bytes_per_output_frame * 1000000 / output_sample_rate;

        int available_bytes = SDL_AudioStreamAvailable(audio_stream);
        if (available_bytes < 0) {
            audio_telemetry.conversion_errors++;
            std::fprintf(stderr, "Error reading SDL audio stream availability: %s\n", SDL_GetError());
            return;
        }
        available_bytes -= available_bytes % static_cast<int>(output_channels * sizeof(float));
        converted_buffer.resize(static_cast<size_t>(available_bytes) / sizeof(float));
        int converted_bytes = 0;
        if (available_bytes != 0) {
            converted_bytes = SDL_AudioStreamGet(
                audio_stream, converted_buffer.data(), available_bytes);
            if (converted_bytes < 0) {
                audio_telemetry.conversion_errors++;
                std::fprintf(stderr, "Error draining SDL audio stream: %s\n", SDL_GetError());
                return;
            }
        }
        uint32_t queue_bytes = static_cast<uint32_t>(converted_bytes);
        float* samples_to_queue = converted_buffer.data();

        // Let N64ModernRuntime's get_frames_remaining feedback regulate
        // production. Never shorten already-rendered PCM to catch up: that
        // creates discontinuities and pitch/time jumps.
        audio_telemetry.callbacks++;
        audio_telemetry.input_frames += sample_count / input_channels;
        audio_telemetry.output_frames +=
            queue_bytes / (output_channels * sizeof(float));
        audio_telemetry.peak_queue_us = std::max(audio_telemetry.peak_queue_us, queued_input_us);
        if (queued_input_us >= 100000) audio_telemetry.over_100ms_callbacks++;

        if (queue_bytes != 0) {
            const uint32_t output_frame_count =
                queue_bytes / (output_channels * sizeof(float));
            if (output_frame_count != 0) {
                if (has_previous_output_frame) {
                    const float left_delta = std::abs(samples_to_queue[0] - previous_output_frame[0]);
                    const float right_delta = std::abs(samples_to_queue[1] - previous_output_frame[1]);
                    const uint32_t delta_ppm = static_cast<uint32_t>(
                        std::lround(std::max(left_delta, right_delta) * 1000000.0f));
                    audio_telemetry.boundary_delta_sum_ppm += delta_ppm;
                    audio_telemetry.boundary_count++;
                    audio_telemetry.peak_boundary_delta_ppm = std::max(
                        audio_telemetry.peak_boundary_delta_ppm, delta_ppm);
                }
                for (uint32_t frame = 1; frame < output_frame_count; ++frame) {
                    const size_t current = frame * output_channels;
                    const size_t previous = current - output_channels;
                    const float left_delta = std::abs(
                        samples_to_queue[current + 0] - samples_to_queue[previous + 0]);
                    const float right_delta = std::abs(
                        samples_to_queue[current + 1] - samples_to_queue[previous + 1]);
                    const uint32_t delta_ppm = static_cast<uint32_t>(
                        std::lround(std::max(left_delta, right_delta) * 1000000.0f));
                    audio_telemetry.peak_within_delta_ppm = std::max(
                        audio_telemetry.peak_within_delta_ppm, delta_ppm);
                }
                const size_t last = (output_frame_count - 1) * output_channels;
                previous_output_frame[0] = samples_to_queue[last + 0];
                previous_output_frame[1] = samples_to_queue[last + 1];
                has_previous_output_frame = true;
            }

            // Apply the master volume gain to the float PCM before queueing.
            const float gain = audio_volume.load(std::memory_order_relaxed);
            if (gain < 1.0f) {
                uint32_t sample_words = queue_bytes / sizeof(float);
                float* samples = static_cast<float*>(samples_to_queue);
                for (uint32_t i = 0; i < sample_words; i++) {
                    samples[i] *= gain;
                }
            }

            if (SDL_QueueAudio(audio_device, samples_to_queue, queue_bytes) < 0) {
                audio_telemetry.queue_errors++;
                std::fprintf(stderr, "Error queueing audio: %s\n", SDL_GetError());
            }
        }

        const uint64_t queued_output_us =
            uint64_t(SDL_GetQueuedAudioSize(audio_device)) /
            (output_channels * sizeof(float)) * 1000000 / output_sample_rate;
        audio_telemetry.peak_queue_us = std::max(audio_telemetry.peak_queue_us, queued_output_us);
        report_audio_telemetry(queued_output_us);
    }

    size_t get_frames_remaining() {
        if (audio_device == 0) {
            return 0;
        }

        uint64_t buffered_byte_count = SDL_GetQueuedAudioSize(audio_device);
        if (audio_stream != nullptr) {
            const int converted_bytes = SDL_AudioStreamAvailable(audio_stream);
            if (converted_bytes > 0) {
                buffered_byte_count += static_cast<uint64_t>(converted_bytes);
            }
        }
        buffered_byte_count = buffered_byte_count * input_channels * sample_rate / output_sample_rate / output_channels;
        return static_cast<size_t>(buffered_byte_count / bytes_per_input_frame);
    }

    void poll_input() {
        // SDL event pumping belongs to the host window thread; the game input
        // callback can run on a game/runtime thread.
    }

    float normalize_axis(Sint16 value) {
        if (std::abs(value) < 8000) {
            return 0.0f;
        }
        return std::clamp(static_cast<float>(value) / 32767.0f, -1.0f, 1.0f);
    }

    float gamepad_binding_strength(const GamepadBinding& binding) {
        if (controller == nullptr) {
            return 0.0f;
        }

        if (binding.kind == GamepadBindingKind::Button) {
            if (binding.code < 0 || binding.code >= SDL_CONTROLLER_BUTTON_MAX) {
                return 0.0f;
            }
            return SDL_GameControllerGetButton(controller, static_cast<SDL_GameControllerButton>(binding.code)) ? 1.0f : 0.0f;
        }

        if (binding.code < 0 || binding.code >= SDL_CONTROLLER_AXIS_MAX) {
            return 0.0f;
        }

        const float axis_value = normalize_axis(SDL_GameControllerGetAxis(controller, static_cast<SDL_GameControllerAxis>(binding.code)));
        if (binding.kind == GamepadBindingKind::AxisPositive) {
            return std::max(axis_value, 0.0f);
        }
        return std::max(-axis_value, 0.0f);
    }

    void apply_input_action(int action_index, float strength, uint16_t& out_buttons, float& out_x, float& out_y) {
        if (action_index < 0 || action_index >= input_action_count || strength <= 0.0f) {
            return;
        }

        const InputActionDescriptor& action = input_actions[action_index];
        if (action.button != 0 && strength >= 0.5f) {
            out_buttons |= action.button;
        }
        out_x += action.axis_x * strength;
        out_y += action.axis_y * strength;
    }

    bool get_input(int controller_num, uint16_t* buttons, float* x, float* y) {
        if (controller_num != 0) {
            return false;
        }

        uint16_t out_buttons = 0;
        float out_x = 0.0f;
        float out_y = 0.0f;

        AppInputSettings input_snapshot{};
        {
            std::lock_guard<std::mutex> lock(settings_mutex);
            input_snapshot = input_settings;
        }

        const Uint8* keys = SDL_GetKeyboardState(nullptr);
        for (int i = 0; i < input_action_count; i++) {
            const SDL_Scancode scancode = input_snapshot.keyboard_bindings[i];
            uint8_t remaining = keyboard_tap_latches[i].load(std::memory_order_acquire);
            bool tapped = false;
            while (remaining != 0) {
                if (keyboard_tap_latches[i].compare_exchange_weak(
                        remaining, static_cast<uint8_t>(remaining - 1),
                        std::memory_order_acq_rel, std::memory_order_acquire)) {
                    tapped = true;
                    break;
                }
            }
            if (tapped || (scancode > SDL_SCANCODE_UNKNOWN && scancode < SDL_NUM_SCANCODES && keys[scancode])) {
                apply_input_action(i, 1.0f, out_buttons, out_x, out_y);
            }

            apply_input_action(i, gamepad_binding_strength(input_snapshot.gamepad_bindings[i]), out_buttons, out_x, out_y);
        }

        // Touch overlay state from the Apple shell (iOS).
#if defined(__APPLE__) && TARGET_OS_IPHONE
        uint16_t touch_btns = 0;
        float touch_x = 0.0f;
        float touch_y = 0.0f;
        paperpad_touch_snapshot(&touch_btns, &touch_x, &touch_y);
        out_buttons |= touch_btns;
        out_x += touch_x;
        out_y += touch_y;
#else
        out_buttons |= touch_buttons.load(std::memory_order_relaxed);
        out_x += touch_stick_x.load(std::memory_order_relaxed);
        out_y += touch_stick_y.load(std::memory_order_relaxed);
#endif

        *buttons = out_buttons;
        *x = std::clamp(out_x, -1.0f, 1.0f);
        *y = std::clamp(out_y, -1.0f, 1.0f);
        return true;
    }

    void set_rumble(int, bool) {
    }

    ultramodern::input::connected_device_info_t get_connected_device_info(int controller_num) {
        if (controller_num != 0) {
            return { ultramodern::input::Device::None, ultramodern::input::Pak::None };
        }
        return { ultramodern::input::Device::Controller, ultramodern::input::Pak::RumblePak };
    }

    RspUcodeFunc* get_rsp_microcode(const OSTask* task) {
        // Audio (M_AUDTASK) is handled by the runtime's HLE NAUDIO backend
        // (mupen64plus-rsp-hle) since 2026-08-05; the recompiled n_aspMain
        // ucode is broken for Paper Mario because it omits RSP boot-register
        // and DMEM setup, and used to flood errors / spin forever. See
        // KNOWN-ISSUES.md macOS #1. PAPERPAD_DROP_AUDIO_RSP=1 remains as a
        // legacy escape hatch.
        static const bool drop_audio_rsp = []() {
            const char* v = std::getenv("PAPERPAD_DROP_AUDIO_RSP");
            return v != nullptr && v[0] != '\0' && v[0] != '0';
        }();
        if (drop_audio_rsp && task->t.type == M_AUDTASK) {
            return nullptr;
        }
        // M_AUDTASK is consumed before this callback by the pinned runtime's
        // NAUDIO HLE backend, so no recompiled audio microcode is required.
        std::fprintf(stderr, "Unknown non-graphics RSP task type: %u\n", task->t.type);
        return nullptr;
    }

    std::string get_game_thread_name(const OSThread* thread) {
        return "PM " + std::to_string(thread ? thread->id : 0);
    }

    std::filesystem::path installed_rom_path() {
        return app_config_path() / "pm.n64.us.z64";
    }

    const char* rom_validation_message(recomp::RomValidationError error) {
        switch (error) {
        case recomp::RomValidationError::FailedToOpen:
            return "Could not open the selected file. Please choose your legally dumped Paper Mario (U) ROM.";
        case recomp::RomValidationError::NotARom:
            return "That file does not look like an N64 ROM. Please choose your legally dumped Paper Mario (U) ROM.";
        case recomp::RomValidationError::IncorrectRom:
            return "That is not the supported Paper Mario (U) ROM. Please choose your legally dumped US Paper Mario ROM.";
        case recomp::RomValidationError::NotYet:
            return "That Paper Mario ROM is not supported by this build yet. Please choose the supported US Paper Mario ROM.";
        case recomp::RomValidationError::IncorrectVersion:
            return "That is a Paper Mario ROM, but not the supported US version. Please choose Paper Mario (U).";
        case recomp::RomValidationError::OtherError:
        default:
            return "PaperPad could not validate that ROM. Please choose your legally dumped Paper Mario (U) ROM.";
        }
    }

    bool install_rom_from_path(const std::filesystem::path& rom_path, std::u8string& game_id) {
        auto rom_result = recomp::select_rom(rom_path, game_id);
        if (rom_result == recomp::RomValidationError::Good) {
            if (recomp::load_stored_rom(game_id)) {
                return true;
            }

            show_message("The ROM validated, but PaperPad could not save it into its user folder.");
            return false;
        }

        std::fprintf(stderr, "ROM validation failed for %s with error %d\n", rom_path.c_str(), static_cast<int>(rom_result));
        show_message(rom_validation_message(rom_result));
        return false;
    }

    bool ensure_rom_installed(int argc, char** argv, std::u8string& game_id) {
        if (std::filesystem::exists(installed_rom_path()) && recomp::load_stored_rom(game_id)) {
            return true;
        }

        // iOS: the shell installs the validated ROM at <App Support>/baserom.z64
        // and chdirs into that directory before calling the game entry.
        const std::filesystem::path cwd_rom = std::filesystem::current_path() / "baserom.z64";
        if (std::filesystem::exists(cwd_rom)) {
            if (install_rom_from_path(cwd_rom, game_id)) {
                return true;
            }
        }

        if (argc > 1 && install_rom_from_path(std::filesystem::path(argv[1]), game_id)) {
            return true;
        }

#if defined(__APPLE__) && !TARGET_OS_IPHONE
        // A Finder-launched .app has no command-line ROM argument. Match the
        // mobile first-run experience with a native macOS picker, then let
        // N64ModernRuntime validate and store the selected ROM privately.
        const char* selected_rom = paperpad_apple_choose_rom_path();
        if (selected_rom != nullptr) {
            const std::filesystem::path selected_path(selected_rom);
            free(const_cast<char*>(selected_rom));
            if (install_rom_from_path(selected_path, game_id)) {
                return true;
            }
        }
#endif

        show_message(
            "PaperPad cannot find an installed ROM. Choose your legally dumped Paper Mario (US) 1.0 ROM to continue, "
            "or pass its path as the first command-line argument.");
        return false;
    }
} // namespace

// Touch bridge (Apple shell).
extern "C" void PaperPad_SetTouchButtons(uint16_t buttons) {
    touch_buttons.store(buttons, std::memory_order_relaxed);
}


extern "C" void PaperPad_SetTouchStick(float x, float y) {
    touch_stick_x.store(x, std::memory_order_relaxed);
    touch_stick_y.store(y, std::memory_order_relaxed);
}

extern "C" void PaperPad_ResetTouchInput(void) {
    touch_buttons.store(0, std::memory_order_relaxed);
    touch_stick_x.store(0.0f, std::memory_order_relaxed);
    touch_stick_y.store(0.0f, std::memory_order_relaxed);
}

// Master audio volume, 0.0 .. 1.0. Applied as a gain on the float PCM in the
// audio thread before SDL_QueueAudio.
extern "C" void PaperPad_SetAudioVolume(float volume) {
    audio_volume.store(std::clamp(volume, 0.0f, 1.0f), std::memory_order_relaxed);
}

// Graphics settings from the iOS settings sheet.
//   resolution_mode: 0 = Auto (scale to window), 1..4 = fixed multiplier
//   aspect_mode:     0 = Original (4:3), 1 = final-presentation fill/crop
//   image_filter:    reserved; PaperPad uses the stable smooth path
// Persisted by the shell; applied here via the runtime's graphics config.
extern "C" void PaperPad_SetGraphicsConfig(int resolution_mode,
                                             int aspect_mode,
                                             int image_filter_mode) {
    (void)image_filter_mode;
    graphics_settings_applied.store(true, std::memory_order_relaxed);
    auto config = ultramodern::renderer::get_graphics_config();
    const int fixed_scale = std::clamp(resolution_mode, 0, 4);
    config.resolution_multiplier = fixed_scale > 0 ? fixed_scale : 2.0;
    switch (fixed_scale) {
        case 1:
            config.res_option = ultramodern::renderer::Resolution::Original;
            break;
        case 2:
            config.res_option = ultramodern::renderer::Resolution::Original2x;
            break;
        case 3:
        case 4:
            config.res_option = ultramodern::renderer::Resolution::Manual;
            break;
        default:
            config.res_option = ultramodern::renderer::Resolution::Auto;
            break;
    }
    config.ar_option = aspect_mode == 1
        ? ultramodern::renderer::AspectRatio::Expand
        : ultramodern::renderer::AspectRatio::Original;
    config.filtering_option = ultramodern::renderer::TextureFiltering::PixelScaling;
    config.upscale_2d = ultramodern::renderer::Upscale2D::ScaledOnly;
    config.three_point_filtering = true;
    ultramodern::renderer::set_graphics_config(config);
}

#if defined(__APPLE__) && TARGET_OS_IPHONE
// iOS: the UIKit shell (SDL_main) calls this after ROM setup + chdir.
extern "C" int paperpad_recomp_main(int argc, char** argv);
#  define PAPERPAD_MAIN paperpad_recomp_main
#else
#  define PAPERPAD_MAIN main
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE
extern "C"
#endif
int PAPERPAD_MAIN(int argc, char** argv) {
    setvbuf(stderr, nullptr, _IONBF, 0);
#if defined(__APPLE__)
    // RT64's automatic API selection prefers D3D12; on Apple, Metal is the
    // supported RHI and must be selected explicitly.
    auto graphics_config = ultramodern::renderer::get_graphics_config();
    // Default to scale-to-window resolution (crisp upscale) unless the iOS
    // settings sheet already applied a saved preference.
    if (!graphics_settings_applied.load(std::memory_order_relaxed)) {
        graphics_config.res_option = ultramodern::renderer::Resolution::Auto;
        graphics_config.ar_option = ultramodern::renderer::AspectRatio::Original;
    }
    graphics_config.api_option = ultramodern::renderer::GraphicsApi::Metal;
    ultramodern::renderer::set_graphics_config(graphics_config);
#endif

    recomp::Version version{};
    if (!recomp::Version::from_string("0.1.0", version)) {
        return EXIT_FAILURE;
    }

    std::u8string game_id = u8"pm.n64.us";
    recomp::GameEntry paper_mario_us{
        .rom_hash = paper_mario_us_xxh3,
        .internal_name = "PAPER MARIO",
        .game_id = game_id,
        .mod_game_id = "",
        .save_type = recomp::SaveType::Flashram,
        .is_enabled = true,
        .decompression_routine = nullptr,
        .has_compressed_code = false,
        .entrypoint_address = get_entrypoint_address(),
        .entrypoint = recomp_entrypoint,
        .on_init_callback = install_recut_frame_hooks,
    };

    recomp::register_config_path(app_config_path());
    recomp::register_game(paper_mario_us);
    paper_mario::register_overlays();

    if (!ensure_rom_installed(argc, argv, game_id)) {
        return EXIT_FAILURE;
    }

    paper_mario::ensure_builtin_texture_pack(app_config_path() / "builtin_textures");

    recomp::rsp::callbacks_t rsp_callbacks{
        .get_rsp_microcode = get_rsp_microcode,
    };

    ultramodern::renderer::callbacks_t renderer_callbacks{
        .create_render_context = paper_mario::renderer::create_render_context,
    };

    ultramodern::audio_callbacks_t audio_callbacks{
        .queue_samples = queue_samples,
        .get_frames_remaining = get_frames_remaining,
        .set_frequency = set_frequency,
    };

    ultramodern::input::callbacks_t input_callbacks{
        .poll_input = poll_input,
        .get_input = get_input,
        .set_rumble = set_rumble,
        .get_connected_device_info = get_connected_device_info,
    };

    ultramodern::gfx_callbacks_t gfx_callbacks{
        .create_gfx = create_gfx,
        .create_window = create_window,
        .update_gfx = update_gfx,
    };

    ultramodern::events::callbacks_t events_callbacks{
        .vi_callback = nullptr,
        .gfx_init_callback = nullptr,
    };
    ultramodern::error_handling::callbacks_t error_callbacks{
        .message_box = show_message,
    };
    ultramodern::threads::callbacks_t thread_callbacks{
        .get_game_thread_name = get_game_thread_name,
    };

    std::thread([game_id]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(750));
        recomp::start_game(game_id);
    }).detach();

    recomp::start(
        version,
        {},
        rsp_callbacks,
        renderer_callbacks,
        audio_callbacks,
        input_callbacks,
        gfx_callbacks,
        events_callbacks,
        error_callbacks,
        thread_callbacks);

    if (controller != nullptr) {
        SDL_GameControllerClose(controller);
        controller = nullptr;
    }
#if defined(__APPLE__) && TARGET_OS_IPHONE
    PaperPad_SetPhysicalControllerConnected(0);
#endif
    if (audio_device != 0) {
        SDL_CloseAudioDevice(audio_device);
        audio_device = 0;
    }
    if (audio_stream != nullptr) {
        SDL_FreeAudioStream(audio_stream);
        audio_stream = nullptr;
    }
    SDL_Quit();

    return EXIT_SUCCESS;
}

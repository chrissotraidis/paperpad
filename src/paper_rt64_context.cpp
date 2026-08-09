#include "paper_rt64_context.h"

#include <algorithm>
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cctype>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

#if defined(_WIN32)
#include <Unknwn.h>
#include <ObjIdl.h>
#include <OleAuto.h>
#endif

#ifndef HLSL_CPU
#define HLSL_CPU
#endif
#include "hle/rt64_application.h"
#include "hle/rt64_state.h"

#include "ultramodern/config.hpp"
#include "ultramodern/ultramodern.hpp"

namespace {
    uint8_t dmem[0x1000];
    uint8_t imem[0x1000];

    unsigned int MI_INTR_REG = 0;
    unsigned int DPC_START_REG = 0;
    unsigned int DPC_END_REG = 0;
    unsigned int DPC_CURRENT_REG = 0;
    unsigned int DPC_STATUS_REG = 0;
    unsigned int DPC_CLOCK_REG = 0;
    unsigned int DPC_BUFBUSY_REG = 0;
    unsigned int DPC_PIPEBUSY_REG = 0;
    unsigned int DPC_TMEM_REG = 0;

    void check_interrupts() {
    }

    RT64::UserConfiguration::AspectRatio to_rt64(ultramodern::renderer::AspectRatio option) {
        switch (option) {
        case ultramodern::renderer::AspectRatio::Original:
            return RT64::UserConfiguration::AspectRatio::Original;
        case ultramodern::renderer::AspectRatio::Expand:
            return RT64::UserConfiguration::AspectRatio::Expand;
        case ultramodern::renderer::AspectRatio::Manual:
            return RT64::UserConfiguration::AspectRatio::Manual;
        default:
            return RT64::UserConfiguration::AspectRatio::Original;
        }
    }

    RT64::UserConfiguration::Antialiasing to_rt64(ultramodern::renderer::Antialiasing option) {
        switch (option) {
        case ultramodern::renderer::Antialiasing::MSAA2X:
            return RT64::UserConfiguration::Antialiasing::MSAA2X;
        case ultramodern::renderer::Antialiasing::MSAA4X:
            return RT64::UserConfiguration::Antialiasing::MSAA4X;
        case ultramodern::renderer::Antialiasing::MSAA8X:
            return RT64::UserConfiguration::Antialiasing::MSAA8X;
        default:
            return RT64::UserConfiguration::Antialiasing::None;
        }
    }

    RT64::UserConfiguration::Resolution to_rt64(ultramodern::renderer::Resolution option) {
        switch (option) {
        case ultramodern::renderer::Resolution::Original:
            return RT64::UserConfiguration::Resolution::Original;
        case ultramodern::renderer::Resolution::Original2x:
            return RT64::UserConfiguration::Resolution::Manual;
        case ultramodern::renderer::Resolution::Auto:
        default:
            return RT64::UserConfiguration::Resolution::WindowIntegerScale;
        }
    }

    ultramodern::renderer::SetupResult map_setup_result(RT64::Application::SetupResult result) {
        switch (result) {
        case RT64::Application::SetupResult::Success:
            return ultramodern::renderer::SetupResult::Success;
        case RT64::Application::SetupResult::DynamicLibrariesNotFound:
            return ultramodern::renderer::SetupResult::DynamicLibrariesNotFound;
        case RT64::Application::SetupResult::InvalidGraphicsAPI:
            return ultramodern::renderer::SetupResult::InvalidGraphicsAPI;
        case RT64::Application::SetupResult::GraphicsAPINotFound:
            return ultramodern::renderer::SetupResult::GraphicsAPINotFound;
        case RT64::Application::SetupResult::GraphicsDeviceNotFound:
            return ultramodern::renderer::SetupResult::GraphicsDeviceNotFound;
        }

        assert(false);
        return ultramodern::renderer::SetupResult::InvalidGraphicsAPI;
    }

    ultramodern::renderer::GraphicsApi map_graphics_api(RT64::UserConfiguration::GraphicsAPI api) {
        switch (api) {
        case RT64::UserConfiguration::GraphicsAPI::D3D12:
            return ultramodern::renderer::GraphicsApi::D3D12;
        case RT64::UserConfiguration::GraphicsAPI::Vulkan:
            return ultramodern::renderer::GraphicsApi::Vulkan;
        case RT64::UserConfiguration::GraphicsAPI::Metal:
            return ultramodern::renderer::GraphicsApi::Metal;
        case RT64::UserConfiguration::GraphicsAPI::Automatic:
            return ultramodern::renderer::GraphicsApi::Auto;
        case RT64::UserConfiguration::GraphicsAPI::OptionCount:
            break;
        }

        assert(false);
        return ultramodern::renderer::GraphicsApi::Auto;
    }

    bool is_texture_replacement_watch_file(const std::filesystem::path& path) {
        if (path.filename() == "rt64.json") {
            return true;
        }

        std::string extension = path.extension().string();
        std::transform(extension.begin(), extension.end(), extension.begin(), [](unsigned char c) {
            return static_cast<char>(std::tolower(c));
        });
        return (extension == ".png") || (extension == ".dds");
    }

    std::filesystem::file_time_type latest_texture_replacement_write_time(const std::filesystem::path& directory) {
        std::filesystem::file_time_type latest{};
        std::error_code error;
        if (!std::filesystem::is_directory(directory, error) || error) {
            return latest;
        }

        std::filesystem::recursive_directory_iterator iterator(
            directory,
            std::filesystem::directory_options::skip_permission_denied,
            error);
        const std::filesystem::recursive_directory_iterator end;
        while (!error && (iterator != end)) {
            if (iterator->is_regular_file(error) && !error && is_texture_replacement_watch_file(iterator->path())) {
                const std::filesystem::file_time_type writeTime = iterator->last_write_time(error);
                if (!error && (writeTime > latest)) {
                    latest = writeTime;
                }
            }

            iterator.increment(error);
        }

        return latest;
    }

    void apply_user_config(RT64::Application* app, const ultramodern::renderer::GraphicsConfig& config) {
        app->userConfig.resolution = to_rt64(config.res_option);
        app->userConfig.resolutionMultiplier = config.res_option == ultramodern::renderer::Resolution::Original2x ? 2.0 : 2.0;
        app->userConfig.downsampleMultiplier = std::clamp(config.ds_option, 1, 32);
        app->userConfig.extAspectRatio = RT64::UserConfiguration::AspectRatio::Original;
        app->userConfig.aspectRatio = to_rt64(config.ar_option);
        app->userConfig.antialiasing = to_rt64(config.msaa_option);
        app->userConfig.filtering = RT64::UserConfiguration::Filtering::AntiAliasedPixelScaling;
        app->userConfig.upscale2D = RT64::UserConfiguration::Upscale2D::ScaledOnly;
        app->userConfig.threePointFiltering = true;
        app->userConfig.displayBuffering = RT64::UserConfiguration::DisplayBuffering::Triple;
        app->userConfig.hardwareResolve = RT64::UserConfiguration::HardwareResolve::Automatic;
        // PaperPad must not pace Paper Mario from the desktop monitor mode. The
        // game owns its 60 VI cadence; display refresh is only a presentation
        // detail.
        app->userConfig.refreshRate = RT64::UserConfiguration::RefreshRate::Original;
        app->userConfig.refreshRateTarget = 60;
        app->userConfig.internalColorFormat =
            config.hpfb_option == ultramodern::renderer::HighPrecisionFramebuffer::On
            ? RT64::UserConfiguration::InternalColorFormat::High
            : (config.hpfb_option == ultramodern::renderer::HighPrecisionFramebuffer::Auto
               ? RT64::UserConfiguration::InternalColorFormat::Automatic
               : RT64::UserConfiguration::InternalColorFormat::Standard);
        app->userConfig.idleWorkActive = false;

        switch (config.api_option) {
        case ultramodern::renderer::GraphicsApi::D3D12:
            app->userConfig.graphicsAPI = RT64::UserConfiguration::GraphicsAPI::D3D12;
            break;
        case ultramodern::renderer::GraphicsApi::Vulkan:
            app->userConfig.graphicsAPI = RT64::UserConfiguration::GraphicsAPI::Vulkan;
            break;
        case ultramodern::renderer::GraphicsApi::Metal:
            app->userConfig.graphicsAPI = RT64::UserConfiguration::GraphicsAPI::Metal;
            break;
        case ultramodern::renderer::GraphicsApi::Auto:
            app->userConfig.graphicsAPI = RT64::UserConfiguration::GraphicsAPI::Automatic;
            break;
        case ultramodern::renderer::GraphicsApi::OptionCount:
            app->userConfig.graphicsAPI = RT64::UserConfiguration::GraphicsAPI::Automatic;
            break;
        }
    }

    class RT64Context final : public ultramodern::renderer::RendererContext {
    public:
        RT64Context(uint8_t* rdram, ultramodern::renderer::WindowHandle window_handle, bool developer_mode) {
            static unsigned char dummy_rom_header[0x40]{};

            RT64::Application::Core core{};
#if defined(_WIN32)
            core.window = window_handle.window;
#elif defined(__linux__) || defined(__ANDROID__)
            core.window = window_handle;
#elif defined(__APPLE__)
            core.window.window = window_handle.window;
            core.window.view = window_handle.view;
#endif
            core.checkInterrupts = check_interrupts;
            core.HEADER = dummy_rom_header;
            core.RDRAM = rdram;
            core.DMEM = dmem;
            core.IMEM = imem;
            core.MI_INTR_REG = &MI_INTR_REG;
            core.DPC_START_REG = &DPC_START_REG;
            core.DPC_END_REG = &DPC_END_REG;
            core.DPC_CURRENT_REG = &DPC_CURRENT_REG;
            core.DPC_STATUS_REG = &DPC_STATUS_REG;
            core.DPC_CLOCK_REG = &DPC_CLOCK_REG;
            core.DPC_BUFBUSY_REG = &DPC_BUFBUSY_REG;
            core.DPC_PIPEBUSY_REG = &DPC_PIPEBUSY_REG;
            core.DPC_TMEM_REG = &DPC_TMEM_REG;

            ultramodern::renderer::ViRegs* vi = ultramodern::renderer::get_vi_regs();
            core.VI_STATUS_REG = &vi->VI_STATUS_REG;
            core.VI_ORIGIN_REG = &vi->VI_ORIGIN_REG;
            core.VI_WIDTH_REG = &vi->VI_WIDTH_REG;
            core.VI_INTR_REG = &vi->VI_INTR_REG;
            core.VI_V_CURRENT_LINE_REG = &vi->VI_V_CURRENT_LINE_REG;
            core.VI_TIMING_REG = &vi->VI_TIMING_REG;
            core.VI_V_SYNC_REG = &vi->VI_V_SYNC_REG;
            core.VI_H_SYNC_REG = &vi->VI_H_SYNC_REG;
            core.VI_LEAP_REG = &vi->VI_LEAP_REG;
            core.VI_H_START_REG = &vi->VI_H_START_REG;
            core.VI_V_START_REG = &vi->VI_V_START_REG;
            core.VI_V_BURST_REG = &vi->VI_V_BURST_REG;
            core.VI_X_SCALE_REG = &vi->VI_X_SCALE_REG;
            core.VI_Y_SCALE_REG = &vi->VI_Y_SCALE_REG;

            RT64::ApplicationConfiguration app_config;
            app_config.useConfigurationFile = false;
            auto config = ultramodern::renderer::get_graphics_config();

            uint32_t thread_id = 0;
#ifdef _WIN32
            thread_id = window_handle.thread_id;
#endif

            auto setup_app = [&](const ultramodern::renderer::GraphicsConfig& setup_config) {
                app = std::make_unique<RT64::Application>(core, app_config);
                apply_user_config(app.get(), setup_config);
                app->userConfig.developerMode = developer_mode;
                app->enhancementConfig.f3dex.forceBranch = true;
                app->enhancementConfig.textureLOD.scale = true;

                setup_result = map_setup_result(app->setup(thread_id));
                chosen_api = map_graphics_api(app->chosenGraphicsAPI);
                return setup_result == ultramodern::renderer::SetupResult::Success;
            };

            setup_app(config);

            if (setup_result != ultramodern::renderer::SetupResult::Success) {
                app.reset();
                return;
            }
            app->setFullScreen(false);
        }

        bool valid() override {
            return app != nullptr;
        }

        bool update_config(const ultramodern::renderer::GraphicsConfig& old_config, const ultramodern::renderer::GraphicsConfig& new_config) override {
            if (!app || old_config == new_config) {
                return false;
            }

            apply_user_config(app.get(), new_config);
            const bool discard_fbs =
                (new_config.res_option != old_config.res_option) ||
                (new_config.ar_option != old_config.ar_option) ||
                (new_config.msaa_option != old_config.msaa_option) ||
                (new_config.hpfb_option != old_config.hpfb_option) ||
                (new_config.ds_option != old_config.ds_option);
            app->updateUserConfig(discard_fbs);
            if (new_config.msaa_option != old_config.msaa_option) {
                app->updateMultisampling();
            }
            if (new_config.wm_option != old_config.wm_option) {
                app->setFullScreen(false);
            }
            return true;
        }

        void enable_instant_present() override {
            // Paper Mario often builds a frame with multiple graphics tasks. Presenting
            // after the first task exposes a half-built framebuffer, which makes 3D
            // models blink while backgrounds remain visible.
        }

        void send_dl(const OSTask* task) override {
            static const bool s_dlhash = [](){ const char* v = std::getenv("PAPERPAD_DL_HASH"); return v != nullptr && v[0] != '0'; }();
            if (s_dlhash) {
                uint32_t ptr = task->t.data_ptr & 0x3FFFFFF;
                uint32_t h = 2166136261u;
                for (int i = 0; i < 64; i++) {
                    uint8_t b = reinterpret_cast<uint8_t*>(app->core.RDRAM)[ptr + i];
                    h ^= b;
                    h *= 16777619u;
                }
                const char* v = std::getenv("PAPERPAD_DL_DUMP");
                if (v != nullptr && v[0] != '0') {
                    fprintf(stderr, "[dl] ptr=0x%X hash=%08X words:", ptr, h);
                    for (int i = 0; i < 24; i++) {
                        uint32_t word;
                        std::memcpy(&word, app->core.RDRAM + ptr + i * 4, 4);
                        fprintf(stderr, " %08X", word);
                    }
                    fprintf(stderr, "\n");
                } else {
                    fprintf(stderr, "[dl] ptr=0x%X hash=%08X\n", ptr, h);
                }
                fflush(stderr);
            }
            app->state->rsp->reset();
            app->interpreter->loadUCodeGBI(task->t.ucode & 0x3FFFFFF, task->t.ucode_data & 0x3FFFFFF, true);
            app->processDisplayLists(app->core.RDRAM, task->t.data_ptr & 0x3FFFFFF, 0, true);
        }

        void update_screen() override {
            app->updateScreen();
        }

        void shutdown() override {
            if (app) {
                app->end();
            }
        }

        void dump_render_state() {
            if (!app) {
                std::fprintf(stderr, "[render] app not ready\n");
                return;
            }
            const auto* res = app->sharedQueueResources.get();
            std::fprintf(stderr,
                "[render] swapchain=%ux%u resolutionScale=%.3f,%.3f\n",
                res ? res->swapChainWidth : 0u,
                res ? res->swapChainHeight : 0u,
                res ? (double)res->resolutionScale.x : 0.0,
                res ? (double)res->resolutionScale.y : 0.0);
            std::fprintf(stderr,
                "[render] userConfig.resolution=%d aspect=%d appUserConfig.resolution=%d multiplier=%.2f\n",
                res ? (int)res->userConfig.resolution : -1,
                res ? (int)res->userConfig.aspectRatio : -1,
                (int)app->userConfig.resolution,
                (double)app->userConfig.resolutionMultiplier);
            std::fprintf(stderr,
                "[render] refreshRate=%d targetRate=%u viOriginalRate=%u swapRate=%u\n",
                (int)app->userConfig.refreshRate,
                res ? res->targetRate : 0u,
                res ? res->viOriginalRate : 0u,
                res ? res->swapChainRate : 0u);
            RT64::VI vi = app->core.decodeVI();
            hlslpp::uint2 fb = vi.fbSize();
            std::fprintf(stderr,
                "[render] vi width=%u fbSize=%ux%u origin=0x%X xScale=%.3f yScale=%.3f hStart=%d-%d vStart=%d-%d\n",
                vi.width, (unsigned)fb.x, (unsigned)fb.y,
                vi.origin,
                (double)vi.xScaleFloat(), (double)vi.yScaleFloat(),
                vi.hRegion.hStart, vi.hRegion.hEnd,
                vi.vRegion.vStart, vi.vRegion.vEnd);
            // Fast origin burst: catches VI-buffer alternation (double
            // buffering) that would explain full/partial frame flashing.
            // Written to a file to avoid interleaving with stderr.
            static FILE* burst_f = [] {
                const char* p = std::getenv("PAPERPAD_ORIGIN_BURST");
                FILE* f = p != nullptr && p[0] != '0'
                    ? std::fopen("origin_burst.txt", "w")
                    : nullptr;
                return f;
            }();
            if (burst_f != nullptr) {
                for (int i = 0; i < 40; i++) {
                    std::fprintf(burst_f, "0x%X\n", (unsigned)app->core.decodeVI().origin);
                    std::fflush(burst_f);
                    std::this_thread::sleep_for(std::chrono::milliseconds(25));
                }
            }
        }

        uint32_t get_display_framerate() const override {
            if (!app) {
                return 60;
            }

            const uint32_t monitor_rate = app->presentQueue->ext.sharedResources->swapChainRate;
            return monitor_rate != 0 ? monitor_rate : 60;
        }

        uint64_t get_presented_frame_count() const override {
            return app
                ? app->presentQueue->ext.sharedResources->presentedFrameCount.load(std::memory_order_relaxed)
                : 0;
        }

        float get_resolution_scale() const override {
            if (!app || app->sharedQueueResources->swapChainHeight == 0) {
                return 1.0f;
            }
            constexpr int reference_height = 240;
            return std::max(float((app->sharedQueueResources->swapChainHeight + reference_height - 1) / reference_height), 1.0f);
        }

    private:
        std::unique_ptr<RT64::Application> app;
    };
}

// Runtime render-state probe for the health logger: the swapchain size, the
// resolution scale RT64 picked, and the VI-derived framebuffer size. Lets a
// "zoomed/cropped" report be checked against the actual numbers instead of
// guessed at.
namespace {
    RT64Context* g_probe_context = nullptr;
}

extern "C" int paperpad_dump_render_state(void) {
    if (g_probe_context != nullptr) {
        g_probe_context->dump_render_state();
        return 1;
    }
    fprintf(stderr, "[render] probe context not registered\n");
    return 0;
}

std::unique_ptr<ultramodern::renderer::RendererContext> paper_mario::renderer::create_render_context(
    uint8_t* rdram,
    ultramodern::renderer::WindowHandle window_handle,
    bool developer_mode) {
    auto context = std::make_unique<RT64Context>(rdram, window_handle, developer_mode);
    g_probe_context = context.get();
    return context;
}

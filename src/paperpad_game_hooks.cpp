#include "paperpad_game_hooks.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cstring>

namespace {
    constexpr gpr paper_mario_cameras_vram = 0x800B1D80;
    constexpr gpr paper_mario_game_status_vram = 0x80074024;
    constexpr gpr paper_mario_current_save_file_vram = 0x800DACC0;
    constexpr gpr camera_size = 0x558;
    constexpr gpr matrix_offset = 0xD4;
    constexpr uint32_t kmr_02_return_to_village_start = 0x802497F4;
    constexpr uint32_t kmr_02_return_to_village_end =
        kmr_02_return_to_village_start + 7060;

    float guest_float(uint8_t* rdram, gpr address) {
        const uint32_t bits = static_cast<uint32_t>(MEM_W(0, address));
        float value = 0.0f;
        std::memcpy(&value, &bits, sizeof(value));
        return value;
    }

    float register_float(gpr value) {
        const uint32_t bits = static_cast<uint32_t>(value);
        float result = 0.0f;
        std::memcpy(&result, &bits, sizeof(result));
        return result;
    }

    bool valid_guest_range(gpr address, uint32_t size = 1) {
        constexpr uint32_t rdram_start = 0x80000000;
        constexpr uint32_t rdram_end = 0x80800000;
        const uint32_t start = static_cast<uint32_t>(address);
        return start >= rdram_start && size <= rdram_end - rdram_start
            && start <= rdram_end - size;
    }
}

extern "C" void paperpad_get_screen_coords(uint8_t* rdram, recomp_context* ctx) {
    // get_screen_coords(s32 camID, f32 x, f32 y, f32 z,
    //                   s32* screenX, s32* screenY, s32* screenZ)
    // The first four arguments are in a0-a3. The three output pointers are in
    // the caller's argument-save area because this hook runs before the
    // original function changes sp.
    const int32_t camera_id = static_cast<int32_t>(ctx->r4);
    const float x = register_float(ctx->r5);
    const float y = register_float(ctx->r6);
    const float z = register_float(ctx->r7);
    const gpr screen_x_address = static_cast<gpr>(
        static_cast<uint32_t>(MEM_W(0x10, ctx->r29)));
    const gpr screen_y_address = static_cast<gpr>(
        static_cast<uint32_t>(MEM_W(0x14, ctx->r29)));
    const gpr screen_z_address = static_cast<gpr>(
        static_cast<uint32_t>(MEM_W(0x18, ctx->r29)));

    const gpr camera = paper_mario_cameras_vram
        + static_cast<gpr>(camera_id) * camera_size;
    float matrix[4][4]{};
    for (int row = 0; row < 4; row++) {
        for (int column = 0; column < 4; column++) {
            matrix[row][column] = guest_float(
                rdram, camera + matrix_offset
                    + static_cast<gpr>((row * 4 + column) * sizeof(float)));
        }
    }

    // Match transform_point and get_screen_coords from the US 1.0 game.
    const float tx = matrix[0][0] * x + matrix[1][0] * y
        + matrix[2][0] * z + matrix[3][0];
    const float ty = matrix[0][1] * x + matrix[1][1] * y
        + matrix[2][1] * z + matrix[3][1];
    const float tz = matrix[0][2] * x + matrix[1][2] * y
        + matrix[2][2] * z + matrix[3][2];
    const float tw = matrix[0][3] * x + matrix[1][3] * y
        + matrix[2][3] * z + matrix[3][3];

    int32_t screen_z = std::clamp(static_cast<int32_t>(tz + 5000.0f), 0, 10000);
    int32_t screen_x = 0;
    int32_t screen_y = 0;
    if (!(static_cast<double>(tw) < 0.01
          && static_cast<double>(tw) > -0.01)) {
        const int32_t viewport_width = MEM_H(0x0A, camera);
        const int32_t viewport_height = MEM_H(0x0C, camera);
        const int32_t viewport_x = MEM_H(0x0E, camera);
        const int32_t viewport_y = MEM_H(0x10, camera);
        const float inverse_w = 1.0f / tw;
        screen_x = static_cast<int32_t>(
            (viewport_width / 2)
            + tx * inverse_w * static_cast<float>(viewport_width) * 0.5f)
            + viewport_x;
        screen_y = static_cast<int32_t>(
            (viewport_height / 2)
            - ty * inverse_w * static_cast<float>(viewport_height) * 0.5f)
            + viewport_y;
    } else {
        screen_z = 0;
    }

    MEM_W(0, screen_x_address) = screen_x;
    MEM_W(0, screen_y_address) = screen_y;
    MEM_W(0, screen_z_address) = screen_z;
}

extern "C" void paperpad_trace_npc_move_to(uint8_t* rdram, recomp_context* ctx) {
    // Injected at NpcMoveTo's single return boundary, before saved registers
    // are restored. r18 is the Evt*, r16 is the resolved Npc*, and r2 is the
    // original API result. This observes the original implementation only.
    const gpr script = static_cast<gpr>(static_cast<uint32_t>(ctx->r18));
    const gpr npc = static_cast<gpr>(static_cast<uint32_t>(ctx->r16));
    if (!valid_guest_range(script, 0x168) || !valid_guest_range(npc, 0xA5)) {
        return;
    }

    const int area = MEM_H(0x86, paper_mario_game_status_vram);
    const int map = MEM_H(0x8C, paper_mario_game_status_vram);
    const int story = static_cast<int8_t>(
        MEM_B(0x10B0, paper_mario_current_save_file_vram));
    const uint32_t first_line = static_cast<uint32_t>(MEM_W(0x15C, script));
    if (area != 0 || map != 1
        || first_line < kmr_02_return_to_village_start
        || first_line >= kmr_02_return_to_village_end) {
        return;
    }

    struct TraceSlot {
        gpr script = 0;
        gpr npc = 0;
        int result = -1;
        int duration = -1;
        std::chrono::steady_clock::time_point last{};
    };
    static std::array<TraceSlot, 8> slots{};
    TraceSlot* slot = nullptr;
    for (TraceSlot& candidate : slots) {
        if (candidate.script == script && candidate.npc == npc) {
            slot = &candidate;
            break;
        }
        if (slot == nullptr && candidate.script == 0) {
            slot = &candidate;
        }
    }
    if (slot == nullptr) {
        slot = &slots[static_cast<uint32_t>(script) % slots.size()];
    }

    const int result = static_cast<int32_t>(ctx->r2);
    const int duration = static_cast<int16_t>(MEM_H(0x8E, npc));
    const auto now = std::chrono::steady_clock::now();
    const bool changed = slot->script != script || slot->npc != npc
        || slot->result != result || slot->duration != duration;
    if (!changed && now - slot->last < std::chrono::milliseconds(500)) {
        return;
    }

    std::fprintf(stderr,
        "[npc_move_to] map=%d story=%d script=0x%08x first=0x%08x "
        "line=0x%08x npc=0x%08x id=%d result=%d state=%d "
        "pos=(%.3f,%.3f) goal=(%.3f,%.3f) speed=%.3f duration=%d\n",
        map,
        story,
        static_cast<uint32_t>(script),
        first_line,
        static_cast<uint32_t>(MEM_W(0x164, script)),
        static_cast<uint32_t>(npc),
        static_cast<int8_t>(MEM_B(0xA4, npc)),
        result,
        MEM_W(0x70, script),
        guest_float(rdram, npc + 0x38),
        guest_float(rdram, npc + 0x40),
        guest_float(rdram, npc + 0x60),
        guest_float(rdram, npc + 0x68),
        guest_float(rdram, npc + 0x18),
        duration);

    slot->script = script;
    slot->npc = npc;
    slot->result = result;
    slot->duration = duration;
    slot->last = now;
}

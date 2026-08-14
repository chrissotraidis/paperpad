#pragma once

#include <stdint.h>

#include "recomp.h"

#ifdef __cplusplus
extern "C" {
#endif

// Native replacement for Paper Mario's get_screen_coords. N64Recomp calls
// this from a generated entry hook before the original function prologue, so
// arguments still follow the original o32 register/stack contract.
void paperpad_get_screen_coords(uint8_t* rdram, recomp_context* ctx);

// Read-only diagnostics injected into generated functions. Both hooks run on
// the guest game thread, avoiding cross-thread reads while scripts/NPCs mutate.
void paperpad_trace_game_loop(uint8_t* rdram, recomp_context* ctx);
void paperpad_trace_npc_move_to(uint8_t* rdram, recomp_context* ctx);

#ifdef __cplusplus
}
#endif

#pragma once

#include <SDL.h>

namespace paperpad::input {

// Touch input drives Player 1. A Player 1 controller lets the touch overlay
// auto-hide only when it has the stick and buttons gameplay needs.
inline bool controller_can_play(void* handle) {
    auto* pad = static_cast<SDL_GameController*>(handle);
    return pad != nullptr && SDL_GameControllerGetAttached(pad) &&
        SDL_GameControllerHasAxis(pad, SDL_CONTROLLER_AXIS_LEFTX) &&
        SDL_GameControllerHasAxis(pad, SDL_CONTROLLER_AXIS_LEFTY) &&
        SDL_GameControllerHasButton(pad, SDL_CONTROLLER_BUTTON_A) &&
        SDL_GameControllerHasButton(pad, SDL_CONTROLLER_BUTTON_B) &&
        SDL_GameControllerHasButton(pad, SDL_CONTROLLER_BUTTON_START);
}

} // namespace paperpad::input

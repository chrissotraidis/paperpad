#pragma once
#include <SDL.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
namespace paperpad::boat {
// Match Original's defaults and its ultramodern 127-unit conversion exactly.
inline float normalize_axis(int16_t value) {
    return std::abs(int(value)) < 8000 ? 0.f : std::clamp(value / 32767.f, -1.f, 1.f);
}
inline int8_t n64_axis(float value) { return static_cast<int8_t>(127 * std::clamp(value, -1.f, 1.f)); }
struct ButtonMapping { SDL_GameControllerButton button; uint16_t mask; };
inline constexpr ButtonMapping buttons[] = {
    {SDL_CONTROLLER_BUTTON_A,0x8000},{SDL_CONTROLLER_BUTTON_X,0x4000},{SDL_CONTROLLER_BUTTON_START,0x1000},
    {SDL_CONTROLLER_BUTTON_LEFTSHOULDER,0x0020},{SDL_CONTROLLER_BUTTON_RIGHTSHOULDER,0x0010},
    {SDL_CONTROLLER_BUTTON_DPAD_UP,0x0800},{SDL_CONTROLLER_BUTTON_DPAD_DOWN,0x0400},
    {SDL_CONTROLLER_BUTTON_DPAD_LEFT,0x0200},{SDL_CONTROLLER_BUTTON_DPAD_RIGHT,0x0100}};
struct KeyMapping { SDL_Scancode key; uint16_t mask; int x; int y; };
inline constexpr KeyMapping keys[] = {
    {SDL_SCANCODE_Z,0x8000,0,0},{SDL_SCANCODE_X,0x4000,0,0},{SDL_SCANCODE_RETURN,0x1000,0,0},
    {SDL_SCANCODE_LSHIFT,0x2000,0,0},{SDL_SCANCODE_Q,0x20,0,0},{SDL_SCANCODE_E,0x10,0,0},
    {SDL_SCANCODE_I,0x8,0,0},{SDL_SCANCODE_K,0x4,0,0},{SDL_SCANCODE_J,0x2,0,0},{SDL_SCANCODE_L,0x1,0,0},
    {SDL_SCANCODE_W,0x800,0,0},{SDL_SCANCODE_S,0x400,0,0},{SDL_SCANCODE_A,0x200,0,0},{SDL_SCANCODE_D,0x100,0,0},
    {SDL_SCANCODE_UP,0,0,1},{SDL_SCANCODE_DOWN,0,0,-1},{SDL_SCANCODE_LEFT,0,-1,0},{SDL_SCANCODE_RIGHT,0,1,0}};
}

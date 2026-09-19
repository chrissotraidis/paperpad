#include "input_mapping.h"
#include <cassert>
#include <iostream>
int main() {
    using namespace paperpad::boat;
    assert(normalize_axis(7999)==0 && normalize_axis(-7999)==0);
    assert(normalize_axis(8000)>0 && normalize_axis(-8000)<0);
    assert(n64_axis(normalize_axis(-32768))==-127);
    assert(n64_axis(normalize_axis(32767))==127);
    assert(n64_axis(2)==127 && n64_axis(-2)==-127 && n64_axis(0)==0);
    assert(n64_axis(.5f)==63 && n64_axis(-.5f)==-63);
    assert(n64_axis(.5f + -.5f)==0); // opposing physical/touch input cancels
    uint16_t mask=0;for(auto mapping:buttons)mask|=mapping.mask;
    assert(mask==0xDF30);
    assert(buttons[0].button==SDL_CONTROLLER_BUTTON_A && buttons[0].mask==0x8000);
    assert(buttons[1].button==SDL_CONTROLLER_BUTTON_X && buttons[1].mask==0x4000);
    assert(keys[0].key==SDL_SCANCODE_Z && keys[0].mask==0x8000);
    assert(keys[1].key==SDL_SCANCODE_X && keys[1].mask==0x4000);
    assert(keys[14].key==SDL_SCANCODE_UP && keys[14].y==1);
    std::cout<<"Original-compatible input: deadzone, 127-unit stick range, clamping, composition and button/keyboard mappings passed.\n";
}

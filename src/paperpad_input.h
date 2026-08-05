#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Shared normalized N64 input bridge between the Apple shell (touch overlay)
// and the recompiled game's poll path. The iOS/UIKit shell writes touch state
// here; PaperPad's SDL poll path ORs it into controller 0.
void PaperPad_SetTouchButtons(uint16_t buttons);
void PaperPad_SetTouchStick(float x, float y);
void PaperPad_ResetTouchInput(void);

#ifdef __cplusplus
}
#endif

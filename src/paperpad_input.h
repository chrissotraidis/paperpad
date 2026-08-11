#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Shared normalized N64 input bridge between the Apple shell (touch overlay)
// and the recompiled game's poll path. The iOS/UIKit shell writes touch state
// here; PaperPad's SDL poll path ORs it into controller 0.
void PaperPad_SetTouchButtons(uint16_t buttons);
void PaperPad_SetTouchStick(float x, float y);
void PaperPad_ResetTouchInput(void);
// Hides gameplay touch targets while an SDL/iOS physical controller is
// connected, then restores them on disconnect according to the saved toggle.
void PaperPad_SetPhysicalControllerConnected(int connected);
void PaperPad_SetAudioVolume(float volume);
void PaperPad_SetGraphicsConfig(int resolution_mode, int aspect_mode, int image_filter_mode);
// Returns renderer-confirmed state once RT64 has presented a frame. Scale is
// expressed in thousandths to keep this C bridge ABI simple.
int PaperPad_GetEffectiveRenderState(uint32_t* scale_milli,
                                     uint32_t* internal_width,
                                     uint32_t* internal_height);

#ifdef __cplusplus
}
#endif

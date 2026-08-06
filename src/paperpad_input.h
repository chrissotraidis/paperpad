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
void PaperPad_SetAudioVolume(float volume);
void PaperPad_SetGraphicsConfig(int resolution_mode, int aspect_mode);

#ifdef __cplusplus
}
#endif

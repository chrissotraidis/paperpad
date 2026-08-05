#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Returns a strdup'd path to the Application Support directory (macOS) or
// the app container's Library/Application Support (iOS), or nullptr on
// failure. Caller frees. Empty on non-Apple platforms.
const char* paperpad_apple_application_support_dir(void);

// Debug diagnostics (iOS only): logs the UIWindow bounds and the CAMetalLayer
// drawable size currently in use. No-op elsewhere.
void paperpad_log_window_diagnostics(void* ui_window, void* metal_layer);

#ifdef __cplusplus
}
#endif

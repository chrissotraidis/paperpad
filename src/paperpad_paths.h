#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Returns a strdup'd path to the Application Support directory (macOS) or
// the app container's Library/Application Support (iOS), or nullptr on
// failure. Caller frees. Empty on non-Apple platforms.
const char* paperpad_apple_application_support_dir(void);

// macOS only: presents a native picker for a Paper Mario ROM and returns a
// strdup'd absolute path, or nullptr when the user cancels. No-op on iOS.
const char* paperpad_apple_choose_rom_path(void);

// Debug diagnostics (iOS only): logs the UIWindow bounds and the CAMetalLayer
// drawable size currently in use. No-op elsewhere.
void paperpad_log_window_diagnostics(void* ui_window, void* metal_layer);

// iOS only: aligns the CAMetalLayer's contentsScale/drawableSize with RT64's
// pixel-sized swapchain math (see KNOWN-ISSUES.md iOS #5). No-op elsewhere.
void paperpad_fix_metal_layer_scale(void* ui_window, void* metal_layer);

#ifdef __cplusplus
}
#endif

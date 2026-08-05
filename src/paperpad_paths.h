#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Returns a strdup'd path to the Application Support directory (macOS) or
// the app container's Library/Application Support (iOS), or nullptr on
// failure. Caller frees. Empty on non-Apple platforms.
const char* paperpad_apple_application_support_dir(void);

#ifdef __cplusplus
}
#endif

#pragma once

// Rotates the prior bounded runtime log, marks the new session active, and
// captures stderr under PaperPad's private Application Support directory.
void paperpad_start_diagnostics_log(void* application_support_root);

// Marks the active session as having reached a normal process exit. A leftover
// active marker on the next launch labels the previous log as a possible crash.
void paperpad_finish_diagnostics_log(void* application_support_root);

// Presents the system share sheet with a bounded diagnostic report and the
// current and previous runtime-log tails. The report never includes ROM or
// save data.
void paperpad_present_diagnostics_share(void* presenter_pointer,
                                        void (^completion)(void));

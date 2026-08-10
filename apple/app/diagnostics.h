#pragma once

// Starts a private, current-session runtime log under PaperPad's Application
// Support directory while preserving stderr output for Simulator diagnostics.
void paperpad_start_diagnostics_log(void* application_support_root);

// Presents the system share sheet with a bounded diagnostic report and the
// current-session runtime log. The report never includes ROM or save data.
void paperpad_present_diagnostics_share(void* presenter_pointer,
                                        void (^completion)(void));

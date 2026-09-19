# PaperPad 0.2.0 — release notes

PaperPad now runs on Harbour Masters’ PaperBoat foundation, with the native Apple controls and conveniences you already know.

## What changed

- New PaperBoat-powered engine, with native full-screen iPad support.
- Floating analog stick: touch the left side to place the stick beneath your thumb; it disappears when released.
- Cleaner three-dot menu with compact Display & Audio and Touch Settings panels.
- Automatic screen-fit rendering resolution up to 4×, manual resolution choices, aspect controls and a live resolution readout.
- Improved diagnostics with PaperPad and upstream links, plus a reviewable GitHub problem-report flow.
- Safer save writes with atomic replacement and backup recovery.
- Launch Original explains how to open the still-supported older version and continue its saves.
- The app and download are named **PaperPad** and **PaperPad.ipa**.

## Saves and upgrading

The new PaperPad and PaperPad Original use separate save formats and app containers. Earlier saves remain in Original; they are not automatically converted. Launch Original requires the Original companion with its launch URL registered. Your new-version saves remain in the new app.

This update was installed in place on the test iPad, and its current save, ROM data and preferences were verified unchanged afterward. Keep the same signing identity and bundle identifier when updating; do not uninstall to work around a signing mismatch.

## Known issue

The title-menu animation can stutter. Startup logs include audio underruns and a temporary frame-rate drop, but the underlying cause has not been isolated. This release does not claim a fix or a measured performance improvement over Original.

## Credits and requirements

Built on [Harbour Masters’ PaperBoat](https://github.com/HarbourMasters/PaperBoat), with credit to the Paper Mario decompilation/DX, libultraship, Torch and all included contributors. PaperPad supplies the Apple integration, native touch interface and diagnostics. Individual licenses and notices are retained.

The unsigned IPA requires user signing and a legally obtained supported game ROM. No ROM, extracted game archive, saves or signing credentials are included.

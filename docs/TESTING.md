# PaperPad test evidence

This is a chronological engineering record. Older failure rows describe the
binary and source state at their timestamp; they are not current release
claims. `docs/STATUS.md` is authoritative for the latest acceptance boundary.
Historical dates use America/Chicago local time. The 2026-08-10 acceptance run
was performed in Europe/Budapest; report timestamps embedded by the diagnostics
file are UTC.

## 2026-08-13–14 longer iPad controller session and physical-iPhone handoff

| Gate | Evidence | Result |
|---|---|---|
| iPad session log | The copied 249,064-byte current-session log spans 1001.6 seconds and 30,000 frames with multiple scene transitions. It contains no fatal/assert, crash, or `game_loop_not_advancing` line | Passed the exercised 16m41s route; not a chapter-spanning test |
| Physical controller | PaperPad identified `KISHI V2`. The session logged analog input and A/B/Z/L/R/Start during sustained play | Partial pass; D-pad, all C directions, and disconnect/reconnect were not observed and remain targeted checks |
| Audio telemetry and listening | All 498 windows report zero conversion and queue errors. Startup briefly drained as expected; one later window peaked at 219.6 ms with 17 over-100-ms samples and then returned to normal without an error. The user's overall assessment was that the game was good | Hands-on route passed; retain the isolated self-recovered excursion as regression evidence and reopen on audible recurrence |
| Touch-layout behavior | The first grouped build made D/C movement mandatory and its `iphone.v6` defaults were physically rejected: C buttons were too far apart and the D-pad was too tight. `iphone.v8` uses screenshot-derived point spacing to correct both geometries. D/C buttons now move individually by default; a persisted Link/Unlink action optionally moves only the selected four-button cluster while preserving its geometry and safe bounds | Physical defect captured; corrected arm64 device build passed; replacement hands-on editor acceptance open |
| Private data capture | The exact iPad ROM normalized to supported SHA-1 `3837f44cda784b466c9a2d99df70d77c322b97a0`; the copied save is exactly 131,072 bytes. Both remain outside source and the clean app bundle | Passed private transfer-input validation |
| Physical iPhone deployment | A temporary private seed copied the exact ROM/save into the iPhone container, then was immediately replaced in place by the preserved clean ROM/save-free app. The clean build launched at a 2532×1170 native drawable and reached active renderer, project audio RSP, recomp heap, and game-loop scene output | Build/install/clean-runtime passed; CoreDevice read-back stalled, so hands-on File Select/save visibility remains required |
| Clean-package audit | The retained and rebuilt clean apps contain no ROM/save file; repository safety and `git diff --check` pass. Local development signing is structurally valid but strict trust evaluation reports the expected `CSSMERR_TP_NOT_TRUSTED` for the local certificate chain | Passed source/package safety; not a distribution-signing claim |

## 2026-08-12 physical-iPad audio and cursor iteration

| Gate | Evidence | Result |
|---|---|---|
| Audio backend | Runtime log reports `Using project-provided recompiled audio microcode`; generation starts Paper Mario's audio function at IMEM `0x1080`, and audio tasks complete synchronously before the guest receives SP completion | Backend/provenance passed |
| Physical listening | The user replayed the early route on the iPad and reported that audio sounded fixed | Provisional hands-on pass for the exercised route; longer-play recurrence remains possible |
| Cursor diagnosis | In the failing physical run, the game wrote the hand at HUD `(165,109)`, exactly viewport-center plus its original `(5,-11)` offset, while the selected Goomba's live position projected to `(204,154)` and visually matched the screenshot | Confirms a shared world-to-screen result defect, not a reason to hardcode a HUD offset |
| Cursor candidate | A supported N64Recomp entry hook replaces shared `get_screen_coords` with the original US 1.0 matrix/viewport math. An isolated guest-memory test passed the o32 register/stack contract, N64 halfword byte order, viewport offsets, integer truncation, and the original near-zero-W clear path. It then passed a 40-second no-input iPad Pro 11-inch (M5), iOS 26.5 Simulator intro smoke test with continuing VI heartbeats and normal rendering. The Simulator was shut down before physical work | Passed ABI/math/build/smoke gates; battle alignment still needs user verification |
| Physical deployment | ROM-free arm64 executable SHA-256 `14c6495c5a58d41c4190dcc0a6fa71302fb2bb0d502a0555387d9de813b51225` passed strict signing and installed in place under `com.chrissotraidis.paperpad`; the app launched without uninstalling or replacing its data container | Passed build/sign/install/launch; saves, ROM, and settings retained in place |
| Candidate runtime log | The untouched current-session log was copied from the iPad after the candidate ran. It records repeated target-selection activity in battle state 18 and continued audio callbacks, but the projection proof line was mistakenly gated to state 17. The local logger now uses state 18; no app relaunch or replacement occurred | Confirms the candidate reached real battles, but does not prove visual alignment; hands-on verdict remains required |
| No-input cursor visual | With every Simulator initially shut down, the local candidate was installed in place on only the iPad Pro 13-inch (M5), iOS 26.5 Simulator. No keyboard, touch, or controller input was sent. Paper Mario's unattended demo reached battle state 18; screenshot SHA-256 `c1be398e1ed26946d9fb9313c89822fd2ac0125bc0b6689cb86db43374812189` shows the white hand directly above the selected middle enemy, consistent with the simultaneous target/projection trace. The Simulator was then shut down | Passed independent Simulator visual route; physical-iPad confirmation remains open |
| Physical cursor acceptance | The user selected and attacked the first trail Goomba and reported that the cursor worked correctly | Passed physical visual acceptance for this route |
| Post-battle crash reproduction | The app exited immediately after the first Goomba died on two consecutive physical-iPad attempts. Reports `PaperPad-2026-08-12-150030.ips` and `PaperPad-2026-08-12-150135.ips` both record `EXC_BAD_ACCESS`/`SIGBUS`, fault address `0x00000003d5d57460`, VI Thread, `trace_vi_frame + 1744` | Failed deterministically; release blocker |
| Crash diagnosis | Binary UUID and instruction-offset mapping place both faults at the temporary battle diagnostic's HUD-element load during actor/HUD teardown. The shared cursor projection hook is absent from both stacks | Root cause confirmed; not a game-code, renderer, or projection-hook crash |
| Crash repair deployment | Removed the cross-thread battle sampler and VI callback; moved the narrower Goompa trace to the post-game-loop boundary with guest-range validation. Device target built successfully; ROM/save-free executable SHA-256 `670ef7402545acd6ade482fb78c20d12133895d1b9adc37660d409870ffcaa6e` passed strict signature and installed/launched in place | Build/sign/install/launch passed; two post-battle hands-on retests open |
| Crash repair hands-on | The user repeated the first-Goomba battle on replacement `670ef740…`; the pointer remained correct and the battle completed without a crash | One physical post-battle pass; former deterministic crash did not reproduce |
| Goompa gate replay | In that continued run, Goompa remained at the gate much longer than expected before it eventually opened. After Mario crossed, Mario and the nearby Goombas stood idle and dialogue/progression did not resume | Failed; guest cutscene/progression blocker remains |
| Live process boundary | Current log was copied while the stalled scene remained on screen. Audio callbacks and touch input events continued through the interval, with no fatal/assert/crash line | App/runtime remained alive; not a whole-process freeze |
| Logger correction | The first post-game-loop overlay logger emitted no Goompa rows because generated direct calls bypass overlay lookup. Maintained N64Recomp hooks now observe the actual `step_game_loop` and `NpcMoveTo` return boundaries on the guest game thread without changing state | Cause of missing trace confirmed; observation seam corrected |
| Diagnostic deployment | ROM/save-free executable SHA-256 `5462f680e9a50af18451e1d2453c06503fffb3601a392c3c6903d55b5c04ea76` passed build/strict signature and installed/launched in place. Exact 131,072-byte save SHA-256 remained `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398` before and after. Startup log records real game-loop frames/input-lock transitions | Passed build/sign/install/preservation/hook-startup gates; Goompa replay required |
| QuickTime-observed Goompa replay | A local unsaved 2:30 QuickTime physical-iPad recording captured the targeted route with device video/audio. The user reported that the prior bug did not appear | One clean physical visual route; recording remains local and unsaved |
| Successful movement trace | The matching live log shows all observed parent/child `NpcMoveTo` calls returning `result=1`. Goompa reached the gate and later village goals; Goombario and Goombaria child movements also completed. The parent advanced to `EVS_PromptForBadgeTutorial`, whose child was normally blocked in `SpeakToPlayer` awaiting dialogue progression | Passed one complete movement/progression route; rules out an unconditional movement-translation failure |
| Goompa diagnostics | The old trace read the disposed map NPC after Goompa became `wPartnerNpc`, producing invalid `y=-1000` movement evidence. A local, compile-tested correction targets the partner object and exact `EVS_ReturnToVillage` script for maps `kmr_03` and `kmr_02`. The US 1.0 ELF confirms `kmr_02_EVS_ReturnToVillage` at `0x802497F4`; direct source/generated comparison found no divergence in `NpcMoveTo` or `npc_move_heading` | Logger target and static movement translation verified; deployment and route evidence remain open |

The pointer, repaired post-battle return, and one Goompa route are physically
accepted. Two more clean Goompa routes remain required because the previously
observed progression failure is intermittent.

## 2026-08-11 physical-feedback iteration

This pass responded to the user's current physical-iPad screenshots and
hands-on feedback. Only the already-booted iPad Pro 13-inch (M5) Simulator,
iOS 26.5, UDID `4E5EE60F-2887-4653-9508-F659BD433121`, was used. No second
Simulator was booted and no keyboard input was sent.

| Gate | Evidence | Result |
|---|---|---|
| Build | Release Simulator build completed for arm64; final executable SHA-256 `4a9d9d461baf5b5e75049243e0a7df50540300227c14f370e7fca3185bb4002d`; Objective-C++ standalone syntax and `git diff --check` passed | Passed build/static checks |
| Physical deployment | The final arm64 device app passed strict signature verification, was ROM/save-free, and had executable SHA-256 `150b0b1305b461f1e11c2b959dd594f08cfd6b2843348b6bfbb23b563c757f25`; it installed in place on iPad14,5 without a container reset, launched, and remained live as PID 734 | Passed build/sign/install/launch/process gates; current human audio/touch/visual acceptance is open |
| Settings affordance | The four bare blue action labels were replaced with 50-point tinted UIKit buttons using SF Symbols, backgrounds, rounded corners, full-width hit targets, and accessibility button traits; Done is a filled primary button | Passed source/build and immediate prior-build iPad Simulator visual/AX inspection; fresh physical review open |
| Auto transparency | Settings visibly reported `Auto is currently 9.00x (2880x2160 internal)` and explained that Auto may exceed the manual 4x cap to fit the screen while source textures retain their original detail | Passed current iPad Simulator visual check |
| Image clarity choice | Physical testing rejected Crisp 2D as visibly worse. The selector and persisted `imageFilter` field were removed, schema advanced to 4, renderer configuration is forced to Smooth, and diagnostics reports `Smooth (fixed)` | Passed source/build/binary-string checks and installed in place; direct settings-screen confirmation open |
| Expand | The setting now writes the chosen mode to both RT64 `aspectRatio` and `extAspectRatio`; the UI persisted `aspect=1`. On the approximately 4:3 iPad, the screen-fit target is already 4:3, so little/no viewport difference is expected | Passed wiring/persistence; wider iPhone comparison open |
| Stick tuning | Touch analog uses a quadratic inner response plus a 1.45× dominant-axis cardinal bias after the shared visual/vector clamp. Full output remains available at the rim and close-axis diagonals are retained | Passed source/build; fresh name-entry and normal-movement playtest open |
| Audio disposition | Prior physical logs remained structurally healthy and PCM stayed below full scale, but hands-on listening confirmed smaller crackle after the resampler fix. The companion mstan recompilation also documents occasional crackle in recompiled N64 synthesis | Host resampler defect remains fixed; synthesis crackle remains a release blocker and was not masked with an unvalidated buffer/gain/filter change |
| Later-game demo | The checksum-validated PaperPad-byte-order level-27 save is staged locally as ignored `ref/demo-saves/Paper Mario - Later Game Demo.bin` with a provenance/safety note; it is absent from Git status and release artifacts | Passed private local fixture preparation; no physical/live save was opened for writing or replaced |
| Visual evidence | `26-paperpad-ipad-image-filter-settings-2026-08-11.jpg` shows current Auto status, Expand, and Sharp Pixels; `27-paperpad-ipad-native-settings-actions-2026-08-11.jpg` records the native action-row styling from the immediately preceding button-identical Simulator build. Source screenshots supplied by the user remain the before evidence | Passed Simulator design comparison; lower action-row physical capture open |

### 14:33–15:20 physical follow-up and replacement deployment

| Gate | Evidence | Result |
|---|---|---|
| User-observed baseline | Physical screenshots showed 4:3 presentation margins; hands-on testing found intermittent music crackle and rejected Crisp 2D. The 15:59 screenshot captures the battle hand far above-left of the selected Spiked Goomba | Defects recorded; pointer mismatch directly evidenced |
| Private File 2 merge | Only the exact 128 KiB live FlashRAM file was read. A checksum-valid level-27 File 2 was written into non-active physical sector 4 at count 192; active File 1 stayed in sector 3 at count 4 and its full-sector SHA-256 remained `c5d67e80cc104b13622c63e9271d0451b5f0af6892f375a05714486ba1797ad5` | Passed structural preservation; visible File 2 load open |
| Save read-back | The exact device save matched merged SHA-256 `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398` before and after the in-place app update | Passed exact-file persistence; no container replacement |
| Fill Screen implementation | Fill Screen keeps regular and extended RT64 projection at Original and center-covers only the completed VI presentation. This applies one final transform to actors and 2D HUD instead of widening them independently | Passed source/patch replay/build/install; physical battle-HUD acceptance open |
| Crisp 2D removal | Crisp 2D behavior, UI, and persistence were removed after physical rejection. Smooth uses anti-aliased pixel scaling, scaled-only 2D upscaling, and N64 three-point filtering | Passed source/build/binary-string checks and installed in place; direct settings-screen confirmation open |
| Controller implementation | Final Info.plist declares controller user interaction; SDL mappings cover the N64 controls; connect hides/clears gameplay touch targets while preserving the utility menu, and disconnect restores according to the saved toggle | Passed source/build/plist audit; physical controller acceptance open |
| Vendor provenance | The complete maintained patch stack, including `ios-expand-visible-area.patch`, replayed cleanly in a fresh local clone; `git diff --check` passed | Passed |
| Device artifact | ROM/save-free arm64 executable SHA-256 `4705532b2b5ebca7752ed0fd78bcc6ae1ac7f19d29a3b7f7c831a857e34d6b33` passed strict signing, installed in place on iPad14,5, preserved the exact save hash, launched, and remained live as PID 761 | Passed build/sign/install/launch/process gates; human acceptance open |
| Current runtime log | Startup completed with a 2732×2048 drawable. Repeated 32→48 kHz telemetry stayed below 100 ms with zero conversion/queue errors and sub-full-scale peaks | Output path structurally healthy; intermittent audible crackle remains release-blocking |

### 15:59 physical defect evidence and source repair

| Gate | Evidence | Result |
|---|---|---|
| Audio output path | A fresh 82,919-byte on-device log during reported flutter showed steady 32→48 kHz conversion, roughly 16–64 ms post-submit queued output, zero conversion errors, zero queue errors, no sampled queue interval above 100 ms, and sub-full-scale PCM. New pre-submit instrumentation then proved the 1.5-VI candidate reached zero 2–7 times per two-second window. With host-queue feedback, synchronous task ordering, and 2.5-VI headroom, only the first startup window drained; the next 36 windows had zero empty/under-5-ms samples, 8.5–13.2 ms minimum headroom, and a bounded <73 ms peak | Confirms a real output-starvation defect and a quantitative fix on the physical iPad. Audible acceptance remains open |
| Battle pointer | The physical screenshot places the selected Spiked Goomba near the lower-right battle area while the hand is far above-left. Source tracing shows Paper Mario uses original 4:3 `get_screen_coords` for the HUD hand while RT64 Expand moved the 3D actor | Cause confirmed; presentation-only Fill repair implemented, physical replay open |
| Image filter | User directly rejected Crisp 2D as worse | Removed from UI, persistence, renderer behavior, diagnostics, and release acceptance |
| Vendor provenance | The revised `ios-expand-visible-area.patch` contains the presentation-only fill flag and replays idempotently against the pinned source tree; both vendor and repository `diff --check` pass | Passed patch/static checks |
| Corrected device build | Xcode Release arm64 build succeeded and signed with the configured development team. The ROM/save-free executable SHA-256 is `9f327e2190649848bf595a0e25797ddca6d950e348a2553fa0bb844dc5758ffa`; the iPad accepted an in-place install and launch | Passed build/sign-at-build/install/launch gates; no claim of hands-on gameplay acceptance |
| Preservation read-back | The post-install 128 KiB device save SHA-256 remained `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398` | Passed exact data preservation; no uninstall or container replacement |

### 16:02 physical progression failure

| Gate | Evidence | Result |
|---|---|---|
| Goomba Village gate sequence | During the Goompa gate-unlock scene, Mario and nearby Goombas remained idle, Mario could not move or initiate NPC dialogue, and Start initially did not register. It eventually registered without restoring normal control or progression | Failed; P0 game-progression blocker |
| Screenshot | The supplied physical-iPad frame records Mario and Goompa partly obscured behind the front fence with the surrounding scene idle | Visual evidence retained privately; it does not establish root cause |
| Cause boundary | No guest script/thread/message snapshot or pre-scene diagnostics comparison has been captured yet | Unknown; do not attribute to input, audio, save, renderer, or scheduler without reproduction evidence |
| Required retest | Preserve a pre-scene save, reproduce three clean runs, and verify cutscene completion plus prompt restoration of Start, movement, and NPC interaction | Open |

### 15:30–15:39 audio-backend feasibility check

| Gate | Evidence | Result |
|---|---|---|
| Sequential scope | Only the already-booted iPad Pro 13-inch (M5) Simulator was used; no second Simulator and no keyboard input | Passed |
| ABI identification | The exact US 1.0 `n_aspMainData` has standard NAUDIO signature `0x0000127c` | Confirms the selected HLE ABI; not audible acceptance |
| Standalone RSP experiment | Current RSPRecomp output compiled, but its first task exited at unhandled target `0x0000` with boot-dependent registers clear. Loading the ABI table and seeding `$29` changed the failure to `0x0001` with `$26/$25` still lacking boot state | Rejected; standalone `n_aspMain` is not a complete RSP task implementation |
| Restoration | All experimental source/runtime integration was removed. The stable HLE build rebuilt, installed in place, launched as PID 86256, rendered the intro with touch controls visible, and produced repeated 32→48 kHz telemetry below 100 ms with zero conversion/queue errors | Passed restoration; audible crackle remains open |
| Simulator controller guard | CoreSimulator reports a synthetic MFi `Gamepad` even without an external controller. Simulator builds now ignore that signal for overlay hiding; physical builds retain controller-driven touch handoff | Passed screenshot/source/build check; physical controller acceptance open |

The experiment narrows the next audio direction to a complete boot+audio RSP
backend (or equivalent LLE path). It does not justify deploying the rejected
microcode path or claiming the crackle fixed.

No Simulator was booted for this physical follow-up, no keyboard input was
sent, and the running app was left for direct user evaluation. Build, PID, and
telemetry evidence do not close audio, visual, controller, battle, or gameplay
acceptance.

This pass deliberately does not claim the remaining audio crackle fixed, does
not claim that higher internal resolution restores original texture detail,
and does not call Expand a crop-to-fill mode on a 4:3 iPad.

## 2026-08-11 iPad Simulator defect pass

This was a development-worktree pass, not release acceptance. The physical
iPad and iPhone routes were not run, and no keyboard/gameplay automation was
sent.

| Gate | Evidence | Result |
|---|---|---|
| Baseline/provenance | `main` began at `e12e22663bdcbba413d5289ae24a4c918d17e7a0`; the iPad Simulator's ROM, `saves/pm.n64.us.bin`, and preferences were backed up, hashed, and preserved across in-place installs | Passed for iPad Simulator; physical-iPad CoreDevice backup stalled and no changed build was installed there |
| Sequential scope | Only iPad Pro 11-inch (M5), iPadOS 26.5, UDID `FE4545BD-7D54-4117-91FA-EB72ED34457A` was booted; the app was stopped before each rebuild/install | Passed |
| Audio diagnosis | Old 10-second source/output capture: source/output power above 14 kHz `1.55e-6`/`8.73e-5`, worst adjacent step `0.0470`/`0.0814`, round-trip correlation `0.99997`; queue stayed below 100 ms with zero conversion/queue errors | The source was clean and the stateless block converter was the measured contamination seam; the earlier queue-decimation path was also removed because it necessarily shortened/pitch-shifted PCM |
| Audio fix | Continuous `SDL_AudioStream` capture: source/output high-band power `1.64e-6`/`1.36e-6`, output worst step `0.0406`, zero conversion/queue errors, and no queue depth above 100 ms | Passed measured Simulator PCM quality; physical-iPad listening remains required |
| Diagnostics rotation | Forced terminate followed by relaunch created 0600 `paperpad-previous.log`, `paperpad-latest.log`, `paperpad-session-active`, and `paperpad-previous-unclean`; the report placed the possible-crash log first and capped each shared tail at 512 KiB | Passed iPad Simulator |
| Diagnostics discovery/share | Three-dot menu showed `Share Diagnostics & Logs…`; Settings share produced the system share sheet and a 20 KiB text file with app/build/system/screen/settings, ROM-present boolean, renderer state, and current/previous logs | Passed; no destination was selected and no report was transmitted |
| Modal touch lifecycle | Gameplay controls and the menu disappeared behind Settings/share; dismissing the share sheet restored the saved controls | Passed visual/AX check |
| Auto resolution | Settings changed from persisted 4x (`Renderer confirms 4.00x (1280x960 internal)`) to Auto (`7.00x (2240x1680 internal)`); the generated report matched Auto and 2240×1680 | Passed renderer-confirmed state and persistence write; all five choices were not re-exercised in this pass |
| Analog defects | Broad pickup now uses the drawn fixed origin and shares the clamped vector with N64 input; released flick retention reduced from six polls to one | Built; hands-on extreme-drag and name-entry acceptance still open |
| Framing | Before: resizable SDL window left the status bar visible. After: iOS borderless window retained full `bounds=1210x834`, Metal `drawable=2420x1668`, hid status chrome, and kept Original centered at maximum 4:3 | Passed iPad Simulator landscape comparison; physical Original/Expand captures remain open |
| Visual quality research | RT64 source confirms runtime DDS/Rice-compatible texture replacement and separate higher-resolution rendering; current Paper Mario packs found publicly are emulator-targeted and lack a verified PaperPad RT64/iOS rights/performance path | No pack bundled or claimed compatible |
| Later-game save research | Runtime/source and live container confirm one 128 KiB FlashRAM file, `saves/pm.n64.us.bin`, containing the game's slots | Format passed; no external save was installed or allowed near the live container |
| Build/warning review | Incremental release Simulator builds link successfully; known vendor warnings remain. Runtime still emits the Simulator-only duplicate accessibility class and UIKit appearance-transition warnings | Build passed; warning cleanup remains open |

## 2026-08-11 iPhone Simulator follow-up

The iPad app was terminated and its Simulator shut down before this route. No
keyboard or gameplay input was sent; the user rotated the simulated device to
landscape.

| Gate | Evidence | Result |
|---|---|---|
| Build provenance | Final ROM-free release Simulator executable SHA-256 `6bf71953e95f51a8a2b7cbca31799ed2fdbb3b97a9f2bd971fa3adb120e45d47`; repository safety and bundle ROM-extension audits passed | Passed; exact final artifact launched after the temporary orientation experiment was removed |
| Target/data preservation | iPhone 17 Pro, iOS 26.5, UDID `19F00332-C249-473D-9AA1-C0060E244F97`; both private ROM copies retained SHA-256 `9ec6d2a5c2fca81ab86312328779fd042b5f3b920bf65df9f6b87b376883cb5b`, and preferences retained `6e2e73fe103688bb63dd53aff8e85f50fafa9a9f5a6a8876071beaba3b70ae84` across the in-place install | Passed; there was no save file in this earlier iPhone test container |
| Launch/visual | Logos, story scenes, title, and early gameplay continued without crop, stale half-frame, or missing layer after the device was held in landscape | Passed rendering route; later screenshot review found that the shipped compact defaults placed R/L edge-to-edge and C-up inside L's footprint, so touch-layout acceptance was reopened and superseded by the v6 correction below |
| Auto transparency | Settings visibly reported `Auto is currently 6.00x (1920x1440 internal)` | Passed renderer-confirmed status on iPhone |
| Diagnostics/modal lifecycle | First-level `Share Diagnostics & Logs…` remained present; Settings generated a 22 KiB text report and system share sheet, no destination was chosen, and controls/menu disappeared during presentation then restored after dismissal | Passed visual/AX check |
| Audio/runtime log | Repeated telemetry stayed below 53 ms queue depth with `over_100ms=0`, `conversion_errors=0`, and `queue_errors=0`; current/previous logs were `0600` | Passed structural/runtime-log check; Simulator output is not physical-device listening acceptance |

This follow-up verifies the current audio, Auto-status, diagnostics, modal, and
framing paths on iPhone Simulator. It is not a new first-run import, name-entry,
extreme-stick-drag, long-soak, or physical-device pass.

## 2026-08-11 private later-game save fixture

This route used a disposable Simulator and private files only. The user's live
iPad Simulator, physical-device container, ROM, preferences, and save were not
opened for writing. No keyboard input was sent.

| Gate | Evidence | Result |
|---|---|---|
| Provenance/license | [GameBanana mod 678655](https://gamebanana.com/mods/678655), “100% Save File [.srm / .fla],” publishes the raw `.fla` under CC BY-NC-ND 4.0; downloaded archive MD5 `89310d6cb2b4b30b1a6074d02300be88` matched its published metadata | Passed as a private test input; the save is not committed, packaged, or redistributed |
| Byte order/format | The 131,072-byte `.fla` was Project64 word-swapped. Reversing each four-byte word produced PaperPad byte order, SHA-256 `e9881da4ae8873aed319697e8a63ec0ee9bcec46663642a9a18381bfa227a175`, beginning with the expected `Mario Story 006` header | Passed PaperPad FlashRAM format check |
| Structural validation | All six physical save sectors passed magic, CRC-complement, and additive-checksum validation; both global copies passed. Logical Files 1 and 2 reported level 27 and seven Star Spirits before launch | Passed US 1.0 save-structure validation |
| Isolation/sequential scope | Only disposable iPad Pro 11-inch (M5), iPadOS 26.5, UDID `8EAB77D1-A8CB-4ADC-A806-7281DB381FF1`, was booted. Its private ROM and converted save were mode `0600`; all other Simulators remained shut down | Passed; no live/user container was modified |
| Runtime route | Touch-only Start/A reached file select, showed Files 1 and 2 at level 27, loaded File 2 into Toad Town, and repeated touch-stick input moved Mario; capture `22-paperpad-later-game-fixture-ipad-2026-08-11.png` records the loaded scene | Passed the exercised late-game load/movement route; not a chapter-spanning playthrough |
| Save preservation | Runtime read/load left `saves/pm.n64.us.bin` at 131,072 bytes, mode `0600`, and the same SHA-256 as the converted input | Passed byte-for-byte preservation for this route |
| Audio/crash telemetry | From 11:01:36–11:05:16 local, 108 audio windows peaked at 52.25 ms queue depth with `over_100ms=0`, `conversion_errors=0`, and `queue_errors=0`; no fatal, assert, signal, exception, or app-crash line appeared | Passed structural/runtime-log check; physical audible quality remains open |

The fixture now supplies a reproducible late-game starting point without
redistributing the save. Named middle-game checkpoints, battles, transitions,
saving, lifecycle recovery, and a chapter-spanning/60-minute soak remain open.

## 2026-08-11 touch-only name-entry follow-up

The disposable iPad Simulator was reused after every other Simulator was shut
down. Its validated late-game save was moved aside intact, PaperPad was launched
with no active save, and the original hash was restored after shutdown. No
keyboard input was sent.

| Gate | Evidence | Result |
|---|---|---|
| Blank-save isolation | The private level-27 fixture was renamed within the disposable container before launch; no new save was committed because name entry was not confirmed. After shutdown it was restored as `saves/pm.n64.us.bin` with unchanged SHA-256 `e9881da4ae8873aed319697e8a63ec0ee9bcec46663642a9a18381bfa227a175` | Passed; live/user saves remained untouched |
| Name-entry route | Touch-only Start/A opened a new file and reached the original character grid; capture `23-paperpad-ipad-name-entry-touch-2026-08-11.png` records the exercised screen | Passed without keyboard input |
| Horizontal gesture | One short rightward stick gesture moved the selector exactly one column, `A` to `B`, and it remained there after a 1.2-second observation | Passed discrete horizontal navigation |
| Vertical gesture | One deliberate downward stick drag moved exactly one row, `B` to lowercase `o`, and stopped | Passed discrete vertical navigation |
| Extreme gestures | Three deliberately far diagonal drags moved the selector by one adjacent row/column per gesture rather than racing across the grid | Passed controlled grid behavior; the automation releases between display frames, so it cannot visually certify the knob's held extreme position |
| Clamp invariant | `publishInput` clamps the touch displacement to the visible stick radius before deriving both `_stickKnob` and the normalized N64 vector | Passed source/invariant review; a physical held-thumb visual check remains open |
| Runtime log | 248 audio telemetry windows peaked at 52.416 ms with no over-100 ms event, conversion error, queue error, fatal, assert, abort, signal, or exception line | Passed the exercised route; not physical audible acceptance |

This closes Simulator name-grid repeat acceptance for discrete touch gestures.
Physical extreme-drag visuals and human name-entry feel remain part of the
device acceptance route.

## 2026-08-11 iPhone touch-only name-entry follow-up

The disposable iPad was shut down before the existing iPhone 17 Pro Simulator,
iOS 26.5, UDID `19F00332-C249-473D-9AA1-C0060E244F97`, was booted. The device
was rotated through the Simulator toolbar and no keyboard input was sent.

| Gate | Evidence | Result |
|---|---|---|
| Data preservation | Both private ROM copies retained SHA-256 `9ec6d2a5c2fca81ab86312328779fd042b5f3b920bf65df9f6b87b376883cb5b`; preferences retained `6e2e73fe103688bb63dd53aff8e85f50fafa9a9f5a6a8876071beaba3b70ae84`; no save existed before or after because the name was not confirmed | Passed preserved-data boundary |
| Name-entry route | Touch-only Start/A opened File 1's name grid in the compact landscape layout; capture `24-paperpad-iphone-name-entry-touch-2026-08-11.png` records the exercised state | Passed without keyboard input |
| Discrete navigation | One rightward touch-stick gesture moved `A → B`; one downward gesture moved `B → o`; each selector position remained stable after a 1.2-second observation | Passed one-column and one-row behavior |
| Runtime log | 73 audio telemetry windows peaked at 53.5 ms with no over-100 ms event, conversion error, queue error, fatal, assert, abort, signal, or exception line | Passed the exercised route; not physical audible acceptance |

Both Simulator device classes now pass discrete touch-stick name-grid
navigation. Physical-device feel and the held extreme-knob visual remain open.

## 2026-08-11 iPhone compact-control correction

The user identified the collision in a visible iPhone 17 Pro Simulator capture.
The iPad layout was not changed and no keyboard input was sent. A final device
state audit found an idle iPad Pro 13-inch Simulator booted in the background;
it had not been used for this route and was shut down immediately. The retained
state has only the iPhone booted.

| Gate | Evidence | Result |
|---|---|---|
| Reproduction | The v5 defaults placed R and L only one shoulder diameter apart, so their outlines touched; C-up began inside L's rendered footprint | Failed v5 compact-layout acceptance; this was a default-layout defect, not saved customization |
| Correction | Phone defaults now leave explicit gaps from R → L → C-up, separate the C cluster, and move Z/B/A into distinct grip targets; the phone layout key advanced from `iphone.v5` to `iphone.v6` while the iPad key remained unchanged | Passed source/geometry review; obsolete v5 phone customization is intentionally not loaded over the corrected defaults |
| Build/provenance | ROM-free release Simulator build succeeded; executable SHA-256 `df389d7165ff6d06b34ddf65393e43af1d61de2a1356ae7ffd1db5ae7fb9b728` | Passed build |
| Preservation | In-place install retained both private ROM copies at SHA-256 `9ec6d2a5c2fca81ab86312328779fd042b5f3b920bf65df9f6b87b376883cb5b` and preferences at `6e2e73fe103688bb63dd53aff8e85f50fafa9a9f5a6a8876071beaba3b70ae84` | Passed explicit read-back; no save exists in this test container |
| Visual result | Gameplay capture `25-paperpad-iphone-controls-separated-2026-08-11.jpg` shows visible space between R/L, L/C-up, each C target, Z/B, and B/A | Passed iPhone 17 Pro Simulator landscape check; physical-iPhone ergonomics remain open |
| Final Simulator state | State audit initially found the iPhone plus an idle background iPad Pro 13-inch (M5); the iPad was shut down and the follow-up listed only iPhone 17 Pro as booted | Final one-Simulator state passed; strict exclusivity during the entire route cannot be claimed |

This correction supersedes the earlier compact-layout claim. It validates
separation on the exercised iPhone size, not every supported phone size or a
physical-device grip test.

## 2026-08-11 late-game frame-pacing leak regression

The validated level-27 File 2 fixture was loaded into Toad Town on the
disposable iPad Simulator. The first sustained run deliberately stopped when
heap evidence contradicted stability; the retained run used the rebuilt
ROM-free app with `metal-drawable-slot-lifetime.patch` applied.

| Gate | Evidence | Result |
|---|---|---|
| Pre-fix sustained run | Over roughly 24 minutes of process lifetime, physical footprint rose `148.7 → 154.2 → 160.0 MiB` while `VM_ALLOCATE` stayed at 255. Heap showed 42,354 live `CAMetalDrawable`, 42,352 drawable-lifetime, and 757,314 `FPInFlightCommandBuffer` objects, plus matching retained arrays | Failed; one swap-chain slot retain leaked per rendered frame even though the earlier serializer/VM-region leak remained fixed |
| Root cause | `MetalSwapChain::acquireTexture` retained each `nextDrawable` and overwrote the slot pointer without releasing the slot's previous retained drawable. Presentation's separate temporary retain/release could not balance that owner | Confirmed direct ownership defect |
| Maintained fix | `patches/rt64/metal-drawable-slot-lifetime.patch` retains the replacement first, releases the previous slot owner, assigns the new drawable, and makes destruction null-safe | Passed reverse check and full clean replay of every maintained RT64 patch against pinned ReCut `098be0a501eecd5bb894a47964061d05eeedc3a2` |
| Rebuild/provenance | Escalated incremental release Simulator build succeeded; ROM-free executable SHA-256 `c7169064de1fee098c6703cccec8b1e38f148e1ea9cb6071b5284a8045fb5500` | Passed build and bundle ROM/save-extension audit |
| Preserved data | Reinstall changed the Simulator data-container UUID but retained both private ROM hashes `9ec6d2a5c2fca81ab86312328779fd042b5f3b920bf65df9f6b87b376883cb5b` and the 128 KiB mode-0600 save hash `e9881da4ae8873aed319697e8a63ec0ee9bcec46663642a9a18381bfa227a175` | Passed explicit post-install readback |
| Post-fix heap | First loaded-scene snapshot: 3 drawables, 3 drawable lifetimes, 72 frame-pacing command buffers, 141.0 MiB physical. After thousands more frames: counts remained exactly `3/3/72`, physical footprint was 130.1 MiB with 145.3 MiB peak | Passed direct per-frame leak regression; live objects stayed bounded to swap-chain/frame-pacing depth |
| Post-fix runtime | Seven sustained audio samples stayed below 49.75 ms peak queue depth with no over-100 ms event, conversion error, or queue error; Toad Town remained rendered and responsive | Passed retained bounded run; audible physical-device quality and the full 60-minute route remain open |

The earlier `255`-region check covered RT64 VM allocation but was not sufficient
to detect this distinct Objective-C FramePacing leak. Future soak acceptance
must include both VM-region/footprint and heap-class counts.

## 2026-08-11 iOS Metal-layer shutdown crash regression

The user supplied the complete iPhone Simulator crash report after the compact
layout review. The incident matched the preceding Simulator shutdown, so the
extended soak was stopped until teardown was corrected.

| Gate | Evidence | Result |
|---|---|---|
| iPhone report | `PaperPad-2026-08-11-122215.ips`, PID 13973, aborted in `CAMetalLayer dealloc` → `MetalSwapChain::~MetalSwapChain` on the Gfx Thread while the main thread joined renderer/event shutdown | Failed pre-fix shutdown; attached report was actionable rather than a gameplay crash |
| Independent reproduction | The pre-fix isolated iPad fixture reached active 2420×1668 rendering, then Simulator shutdown created `PaperPad-2026-08-11-123234.ips` with the same background-thread layer teardown | Failed pre-fix on the second device class; reproduced without keyboard input |
| Root cause | RT64 did not retain `renderWindow.view`, which is an SDL/UIKit-owned `CAMetalLayer`, but its graphics-thread swap-chain destructor unconditionally released it; that release could become the final UIKit layer deallocation off the main thread | Confirmed direct ownership/threading defect |
| Maintained fix | `patches/rt64/ios-metal-view-lifetime.patch` leaves the SDL/UIKit-owned layer untouched on iOS while preserving the existing release on macOS | Passed reverse check and full clean replay of all maintained patches against pinned ReCut |
| iPhone post-fix | ROM-free executable SHA-256 `76c03e8644aed24fc571fa28d63cd4b3176c9c62ad8f17d28adb699b8cc2046d`; active 2622×1206 drawable and audio telemetry confirmed before the same Simulator shutdown | Passed; no third PaperPad report appeared |
| iPad post-fix | In-place fixture update preserved both ROM hashes `9ec6d2a5c2fca81ab86312328779fd042b5f3b920bf65df9f6b87b376883cb5b` and save hash `e9881da4ae8873aed319697e8a63ec0ee9bcec46663642a9a18381bfa227a175`; active 2420×1668 drawable confirmed before shutdown | Passed; report list remained exactly the two pre-fix incidents and no Simulator remained booted |
| Device artifact | Current arm64 iPhoneOS executable SHA-256 `9e7954471ec43465d01031ba2799a6f2110d6e56bb9f2d04acc511518c5a753e`; automatic signing used team `VKDH2T9UTF`, wildcard profile `8b78a5eb-d835-41a7-9578-fbc74823f7e6`, and an Apple Development identity | Passed strict code-sign, entitlement, exact-iPad provisioning, arm64, and ROM-free audits; subsequently installed in place in the recovery pass below |

This closes the reproduced Simulator shutdown crash on both device classes. It
does not replace physical-device lifecycle testing or the unfinished 60-minute
soak.

## 2026-08-11 physical iPad preparation boundary (superseded)

| Gate | Evidence | Result |
|---|---|---|
| Device/sequential scope | All Simulators were shut down; paired iPad Pro 12.9-inch (6th generation), UDID `95937B69-2038-56A0-8069-0EB0484BC2F9`, was rediscovered as available | Passed discovery; no changed app was installed |
| Preservation backup | Bounded CoreDevice copies of `Documents`, a read-only recursive listing of `Library/Application Support/PaperPad`, a direct copy of only `saves/pm.n64.us.bin`, a current 60-second `Documents` retry, and a no-recurse `Documents` listing each acquired the wired tunnel/usage assertion but timed out or returned `Connection interrupted` | Failed host/device file-service gate; no container reset, removal, or install was attempted |
| Device compile/sign | Current source compiled as arm64 iPhoneOS and signed successfully with team `VKDH2T9UTF`; executable SHA-256 `9e7954471ec43465d01031ba2799a6f2110d6e56bb9f2d04acc511518c5a753e` | Passed current signed build; the Xcode-managed wildcard profile includes exact device UDID `00008112-001D485114DBC01E` |
| Signed bundle audit | `codesign --verify --deep --strict` passed; entitlements resolve to `VKDH2T9UTF.com.chrissotraidis.paperpad`; bundle is arm64, iOS 15.0+, iPhone+iPad, and contains no ROM/save-format file | Passed installable artifact boundary; install was withheld during this earlier attempt and later completed in the recovery pass below |

This records the earlier failed attempt without rewriting its evidence. The
CoreDevice recovery and installation below supersede its blocked conclusion.

## 2026-08-11 physical iPad CoreDevice recovery and installation

| Gate | Evidence | Result |
|---|---|---|
| Root-cause isolation | The paired/unlocked iPad, Developer Mode, compatible DDI, wired tunnel, and app listing were healthy. The Mac `CoreDeviceService` process remained wedged at app-container `ReceiveFilesAction`; after terminating PID 12182, a sandboxed fresh lookup was explicitly denied by launchd (`error 159`) | Confirmed two host-side layers: a stalled CoreDevice XPC worker followed by a Codex sandbox Mach-service restriction, not a PaperPad folder or iPad lock failure |
| Correct execution path | Unsandboxed `xcrun devicectl list devices` immediately rediscovered the iPad as `available (paired)`; the same read-only, no-recurse PaperPad `Documents` listing returned `0 files` in 0.603 seconds | Passed CoreDevice discovery and app-container file service; no backup or container mutation was performed |
| Artifact/signature | `build-ios-device/Release/PaperPad.app/PaperPad` was newer than every source and maintained patch file; executable SHA-256 remained `9e7954471ec43465d01031ba2799a6f2110d6e56bb9f2d04acc511518c5a753e`; unsandboxed strict verification passed | Passed current-source and signature checks before install |
| Current worktree gates | Repository safety, pinned-source verification, full maintained-patch replay, shell syntax, Python bytecode compilation, the documented PaperPad-only signed iPhoneOS build, and the ROM-free iOS Simulator build all passed. The rebuilt Simulator executable is arm64 SHA-256 `76c03e8644aed24fc571fa28d63cd4b3176c9c62ad8f17d28adb699b8cc2046d`; the generated CTest project contains no tests | Passed the available source/build gates; device-class runtime evidence remains the manual routes above rather than a nonexistent unit-test suite |
| In-place install | `devicectl device install app` installed bundle `com.chrissotraidis.paperpad` at a new bundle URL without removing or replacing the app data container | Passed signed physical-iPad update; no backup was requested or created |
| Launch/process | `devicectl device process launch --terminate-existing` succeeded; an unfiltered read-only process listing showed the installed executable still running as PID 631 | Passed host-observable launch and retained-process check |
| Physical audio telemetry | One exact read of PaperPad's bounded current-session log contained 190 approximately two-second windows and 22,912 audio callbacks: 12,169,760 source frames became 18,253,152 output frames (1.49988× for 32→48 kHz), maximum reported queue depth was 60.75 ms, and every window reported `over_100ms=0`, `conversion_errors=0`, and `queue_errors=0`. The maximum block-boundary delta was 0.082359 versus a 0.216928 maximum within-block delta; no window's boundary peak exceeded its within-block peak | Passed physical-device structural audio telemetry for this run; no digital capture source was exposed to AVFoundation and no human listening result was supplied, so audible clipping remains open |
| Acceptance boundary | No keyboard, automated gameplay input, UI interaction, audio capture, or human listening was performed in this recovery route | Physical audio, touch feel, visuals, File 1A transition, diagnostics sheet, framing, lifecycle, and longer-session acceptance remain open |

## 2026-08-10 physical iPad development startup

| Gate | Evidence | Result |
|---|---|---|
| Sequential scope | Every Simulator was shut down before the physical-device build and remained shut down; no keyboard or automated gameplay input was sent | Passed |
| Build provenance | Final release arm64 executable SHA-256 `44607a39552c12692296dbcf1f54c98d1166216b1e8b466df4b19665d978ae52`; bundle 0.1.0 (1), iPhone+iPad families, minimum iOS 15.0; no ROM-format file in the final app | Passed |
| Signing | Xcode automatic development signing used an Apple Development identity and an iPad-inclusive provisioning profile; embedded application identifier and team entitlements matched the bundle | Passed on-device; the host's strict certificate-chain check reported `CSSMERR_TP_NOT_TRUSTED`, while iPadOS accepted the signed installation |
| Device | iPad Pro 12.9-inch (6th generation), iPadOS 26.5.2, wired and paired with Developer Mode enabled | Passed install target check |
| Private ROM seed | The local `.v64` normalized to SHA-1 `3837f44cda784b466c9a2d99df70d77c322b97a0`; repeated CoreDevice app-container copies timed out, so a one-time private seed build invoked PaperPad's own validator/importer, then the seed code/resource was removed and the clean ROM-free build was rebuilt and installed over the preserved container | Passed; PaperPad logged `ROM import accepted: Paper Mario US 1.0`; no ROM entered Git or the final `.app` |
| Device-only failure/fix | Initial ROM-backed launch aborted because RT64 attempted `create_directories` at the read-only app-container-root `.rt64`; PaperPad now supplies `Application Support/PaperPad/RT64` as RT64's explicit data path | Passed clean rebuild and relaunch; the permission exception did not recur |
| Final startup | The clean ROM-free build launched against the private ROM, reported a native 2732×2048 Metal drawable, initialized the recomp heap, installed the game-loop hook, and remained running through the observation window | Passed host-observable engine startup; console detachment requested SDL quit and produced exit code 0 |

This is intentionally not recorded as a physical-device gameplay or visual
pass. The native document picker was not used, and no UI, touch, audible audio,
lifecycle, controller, thermal, or long-session behavior was driven or accepted
in this check.

## 2026-08-10 iPad File 1A stability follow-up

| Gate | Evidence | Result |
|---|---|---|
| Build provenance | Release executable SHA-256 `fef7f0188caa4ce448a7d4aaa7b84c6dce94c02e47c46b693b69c1923caf924a`; ROM-free app; existing private ROM/save/preferences preserved byte-for-byte across installs | Passed on iPad Simulator only |
| Sequential scope | Only iPad Pro 11-inch (M5), iPadOS 26.5 was booted; visible Start/A/stick used; no keyboard input | Passed |
| Reported route | 4x launch → title → File 1A → “Mail call!” → Mario's House interior | Passed; sampled transitions showed no stale/half-built frame and the process remained alive |
| Memory regression | Before: RSS about 744 MiB at 32 s, 1.61 GiB at 79 s, 7.67 GiB at 6:58, 8.77 GiB at 8:14. Final: 124.0→124.6 MiB physical and exactly 255 VM allocation regions across 45 idle seconds; 127.1 MiB/255 regions at 3:19 after another scene transition | Passed the exercised stability window; runaway Metal serializer retention removed |
| Audio path | Fixed PCM overlap pointer from half of the discarded float-frame count to the full channel × frame count; final log had no CoreAudio overload/skipped-cycle message | Structural and runtime-log checks passed; audible human acceptance remains open |
| Layer/threading | iOS `CAMetalLayer` display-sync access marshalled to the main thread | Final log had no off-main-layer warning |
| Crash review | One rejected experimental broad workload pool produced PaperPad/SimMetalHost reports at 21:11 and was removed. Retained build produced no later report or fatal/current-session line | Passed retained build; failed experiment documented, not shipped |

This follow-up supersedes the earlier iPad stability conclusion for the current
working tree. It does not roll forward to iPhone Simulator or physical-device
audio acceptance.

## 2026-08-10 iPhone/iPad release-candidate audit

| Gate | Evidence | Result |
|---|---|---|
| Build provenance | `main` base `30a28a9e160ffbebee7a191f2ade5da632528900` plus the reviewed working-tree changes; release executable SHA-256 `e2f90aa4c236665e53355dd42c5b181c7c5b78d7183becd0d6414148ea1e4db7` | Passed; one arm64 ROM-free `build-ios-simulator/Release/PaperPad.app` was installed on both targets |
| Sequential order | iPad Pro 11-inch (M5) was terminated and shut down before iPhone 17 Pro boot; final `simctl list devices` contained no `Booted` device | Passed; never more than one Simulator was booted |
| iPad route | iPad Pro 11-inch (M5), iPadOS 26.5; about 12 minutes; clean first-run screen, ignored normalized ROM seed, logos/title/story, file creation, save selection, Mario's House prologue, menu/settings/share; Start/A used the on-screen controls while file-name direction used Simulator keyboard input | Passed exercised route; no crop, quarter-size viewport, flashing, missing layer, or touch-layout collision observed; captures `15`–`18` under `docs/release-audit/` |
| iPhone route | iPhone 17 Pro, iOS 26.5; about 5 minutes; clean first-run screen, ignored normalized ROM seed, logos/title and file entry using on-screen Start/A, menu/settings/share | Passed exercised route; centered top menu and compact controls remained inside safe areas; captures `19`–`20` under `docs/release-audit/` |
| Resolution selection | Auto, 1x, 2x, 3x, and 4x selected by touch on both device classes | Passed UI selection; this row alone is not renderer proof |
| Renderer scale | Both current-session logs recorded Original at 1x, Manual multipliers 2.00/3.00/4.00, WindowIntegerScale for Auto, and `discard=1` for each live transition | Passed renderer confirmation, including the 3x↔4x framebuffer invalidation path |
| Persistence | iPad was left on 4x, terminated, relaunched, and Settings visibly reopened with 4x selected; the generated report also stated `Resolution: 4x` | Passed for the exercised iPad route; iPhone ended on Automatic and was not separately relaunched for persistence |
| Diagnostics | `PaperPad-Diagnostics.txt` appeared in the system share sheet on both targets; metadata, ROM-present yes/no boundary, privacy note, and current-session tail were inspected | Passed; reports were approximately 3 KiB in these sessions and no share destination was selected |
| Modal touch suppression | Opening menu/settings/share cleared and hid gameplay targets, including the persistent menu button; dismissal restored them according to the enabled Touch Controls setting | Passed by visual and accessibility inspection on both targets |
| Crash/warning review | No new `PaperPad*` DiagnosticReports were created after 18:45 local; current-session logs contained no fatal/assert/crash line | Passed the exercised routes; known non-blocking unbalanced UIKit appearance, duplicate Simulator accessibility-class, `RenderPool`, and `IOSurfaceClientSetSurfaceNotify` diagnostics remain open |

The iPad gameplay route used a directly seeded ignored normalized ROM after the
native clean first-run screen was inspected. The iPhone did the same. This run
therefore confirms the first-run UI and private runtime path, not a fresh
document-picker import. Import and invalid-file behavior retain the prior audit
evidence and remain explicit release-checklist items for future final artifacts.
The full command/process record is in [VALIDATION-2026-08-10.md](VALIDATION-2026-08-10.md).

## 2026-08-09 release audit

| Target | Exercise | Result |
|---|---|---|
| Apple Silicon macOS | Current ROM-backed app launch; intro, name/file flow, early gameplay, keyboard input, clean quit | Passed the exercised route; screenshots `docs/release-audit/03-paperpad-macos-prologue.png` through `06-paperpad-macos-gameplay.png` |
| iPad Pro 11-inch Simulator | ROM-free app install plus private first-run input; touch Start/A/D-pad/analog; title, file creation, early movement, Peach's Castle entry | Passed; no crash during the exercised route |
| iPad Pro 11-inch Simulator | Retina/window correction in portrait and landscape with original 4:3 aspect | Passed; corrected landscape capture `docs/release-audit/10-paperpad-ios-retina-landscape.png`; earlier quarter-size `09-paperpad-ios-first-play.png` retained as before evidence |
| iPad Pro 11-inch Simulator | Persistent PaperPad Menu; volume, resolution, aspect, touch visibility, opacity, layout edit/reset, ROM manager | Controls present and operable; touch visibility toggled off and restored; settings capture `docs/release-audit/11-paperpad-ios-settings.png` |
| Original-game visual comparison | PaperPad opening, file select, and early gameplay compared against Nintendo archive/secondary capture in one review input | Matching 4:3 composition, theater geometry, palette, curtain/checkerboard staging, dialogue styling, and layered cutout presentation; sources recorded in README |
| Apple Silicon macOS final teardown | Final app was launched, rendered, accepted keyboard input, and quit repeatedly; fresh crash reports initially exposed an RT64 workload autorelease fault and then a parked guest-thread/RDRAM race | Both root causes converted into maintained patches; three subsequent launch/render/input/quit cycles produced no new crash reports |
| iPad Pro 11-inch Simulator final shared-runtime rebuild | Rebuilt after the Metal lifetime and Apple process-exit patches; installed the ROM-free app and launched the existing private test container | Build, install, native 2420x1668 drawable, rendering, touch overlay, and accessible PaperPad Menu passed; app terminated and Simulator shut down before any other target |

Remaining release acceptance is listed in `docs/STATUS.md` and
`docs/RELEASE_CHECKLIST.md`; this audit is not a complete-game or physical-device
certification.

## Historical engineering log

| Date | Target | Command/check | Result |
|---|---|---|---|
| 2026-08-05 | host | verified ROM byte order and hashes | v64 sha1 `77693a00418a9d8971b7a005f2001d997e359bff`; normalized z64 sha1 `3837f44cda784b466c9a2d99df70d77c322b97a0` matches pmret US baserom |
| 2026-08-05 17:38 | iPhone 16 Pro Sim | `xcodebuild ... build` (build-ios-sim) | first link fail: `_UTTypeData` + C++-mangled `paperpad_recomp_main`; fixed via `-framework UniformTypeIdentifiers` + `extern "C"` (both sides) |
| 2026-08-05 17:47 | iPhone 16 Pro Sim | iOS build after fixes | **BUILD SUCCEEDED** (`/tmp/iosbuild10.log`) |
| 2026-08-05 17:48 | iPhone 16 Pro Sim | install + `simctl launch` | PID 69104; Metal shaders compiled; game rendered intro (starfield/curtains) — `docs/evidence/ios-iphone-running.png` |
| 2026-08-05 17:48–18:05 | iPhone 16 Pro Sim | repeated plain + `--console-pty` launches | boot stalls permanently mid-intro on landscape runs (4 reproductions); console: `logs/ios-console3.log` (gfx send_dl stops at 1201, RSP flood 1344+); sample: `logs/crashes/` + `/tmp/pp-sample.txt` |
| 2026-08-05 18:1x | macOS (fresh rebuild) | `cmake --build build-macos2` + run with `logs/macos-current.log` | same RSP flood (1677 errors) but game keeps advancing (gfx send_dl 1201→1501); process later exited with known teardown autorelease crash (`logs/crashes/PaperPad-2026-08-05-181521.ips`) |
| 2026-08-05 18:2x | iPhone 16 Pro Sim | touch attach added; relaunch | touch overlay visible: stick, D-pad, A/B/Z, C-buttons, L/R, START — `docs/evidence/ios-iphone-touch-overlay.png` |
| 2026-08-05 20:0x | macOS | runtime instrumented (VI posts, external queue, guest queue) | VI posts retraces at 60/s to `mq=0x800DA4B4` (`~vi_retrace`), but the guest retraceMQ stays empty and `ext_pending` sticks at 1: the delivery depends on a game thread running `dequeue_external_messages`, and all game threads park in `osRecvMesg`. |
| 2026-08-05 20:4x | macOS | vendored SDL2 2.32.10 static linked | launch hang in `SDL_ShowWindow → SDL_RestoreWindow` (Homebrew sdl2-compat/SDL3) eliminated; window created, renderer init OK. |
| 2026-08-05 21:0x | macOS | monitor pump + host-side wake + scheduler wait applied | game plays past the old ~40s freeze: N64 logo, star scene, first cutscene ("Ha ha ha! Yeah! I did!") at ~60fps; `[sgl]` reached 7441 calls (vs 1231 before), `[sched] broadcast` 14900 (vs 2491). Still freezes at a scene transition 1-3 min in (log: `logs/macos-clean-run.log`, `logs/macos-fix2.log`). |
| 2026-08-05 22:39 | macOS | run with `[asset]`/`[script]` hooks | crash in `load_asset_by_name` +84: `fprintf` strlen over a bad rdram pointer during `state_step_intro` map load (`logs/crashes/PaperPad-2026-08-05-223939.ips`). Diagnosed as a stale `build-macos` binary with an older hook; the current `build-macos2` hook copies the asset name to a stack buffer first. |
| 2026-08-05 23:0x | macOS | AOT hook analysis + ROM ucode disassembly | root-caused the audio ucode failure: the recompiled `n_aspMain` never sets `$29` (command pointer = 0x2B0 lives in a DMA subroutine at RSP offset 0x10A0 that RSPRecomp emits as dead code). The ucode reads its own DMEM dispatch table as commands → "Unhandled jump target" flood; dispatch slots 12/14 (`0x1C84`/`0x02B0`) are also missing from the generated switch. Verified with `mips-linux-gnu-objdump` on `generated/rom/baserom.z64` text at `0x4E5A0`. |
| 2026-08-05 23:18 | macOS | HLE audio patch + launch (logs/run-hle1.log) | **No RSP flood; game passes the old t≈68 freeze.** Intro storybook plays; at t≈226 the game loads Toad Town assets (`tik_03`, `trd_09`); opening narration "Today..." advances with A-presses (Z key) through "In the sanctuary of Star Haven"/"Oh dear... What the...?"; health log stable to t=1348 (22+ min). Evidence: `docs/evidence/macos-intro-storybook.jpg`, `macos-gameplay-opening.jpg`, `macos-gameplay-star-haven.jpg`. |
| 2026-08-05 23:26 | iPhone 16 Pro Sim | HLE build install + `simctl launch --console-pty` (logs/run-hle1.log was macOS; iOS log `/tmp/ios-run1.log`) | no RSP flood; intro runs; one stall at t≈256 (health log) with all PM threads parked but SP Task Thread idle — did NOT reproduce on later runs. |
| 2026-08-05 23:45 | iPhone 16 Pro Sim | clean boot + `simctl launch --console-pty` (session log) | **intro completes** (`[intro]` steps 7,141+), story narration plays, Toad Town assets load (`tik_03`/`trd_09`); health log stable to t=450+ (7.5+ min); touch overlay visible (`docs/evidence/ios-iphone-intro-hle.jpg`, `ios-iphone-gameplay.jpg`). |
| 2026-08-05 23:49 | iPhone 16 Pro Sim | freeze diagnostic build (health-log `[freeze]` dump + `ultramodern_get_rdram`) | diagnostic added and verified building on both targets; no stall in the run (dump not triggered). |
| 2026-08-06 00:01 | iPad Pro 11" (M4) Sim | install + `simctl launch --console-pty` | renders intro at full speed (health t=270+, 9 min), touch overlay visible; **window is 667×375 = iPhone-compatibility mode** (`diag: screen=667x375 mode=750x1334 native=750x1334` while the sim framebuffer is 1668×2420). Evidence: `docs/evidence/ipad-intro-hle.png` |
| 2026-08-06 00:1x | iPad Pro 11" (M4) Sim | diagnostics expanded (screen/currentMode/nativeBounds) + `SDL_SetWindowFullscreen` experiment | confirmed the canvas is iPhone-8-sized regardless of fullscreen request; `UIDeviceFamily=[1]` found in the built plist (iPhone-only) — the compatibility-mode cause |
| 2026-08-06 00:2x | build | fix: remove `LSRequiresIPhoneOS`, set `XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"` | rebuilt plist has `UIDeviceFamily=[1,2]`; commit `eca833c` (verification pending a fresh boot) |
| 2026-08-06 01:0x | iPad Pro 11" (M4) Sim | native build + render-state probe (`[render]` lines in health log) | **drawable/swapchain mismatch found**: `swapchain=2420x1668` but `drawable=1210x834 @ contentsScale 1.00` — the present clips the frame to the smaller surface (the zoom/crop). VI `width=320 fbSize=320x240` confirmed the game is 320×240 |
| 2026-08-06 01:1x | iPad Pro 11" (M4) Sim | fix: set CAMetalLayer `contentsScale=nativeScale`, `drawableSize=bounds×nativeScale` (commit `0ab64ce`) | diag now `drawable=2420x1668 @ contentsScale 2.00`; **PAPER MARIO title screen renders in full** (`docs/evidence/ipad-title-full.jpg`); storybook text ("Far, far away, beyond the sky.") fully visible |
| 2026-08-06 01:4x | iPad Pro 11" (M4) Sim | video capture + frame analysis (AVFoundation, 0.1-0.5s sampling) | no sustained full-frame flicker in boot/storybook captures; the perceived "flashing" traced to the 1x internal resolution upscaled 7.5x (soft + shimmer in motion), not a frame-timing bug |
| 2026-08-06 01:5x | iPad Pro 11" (M4) Sim | render probe shows `userConfig.resolution=0 resolutionScale=1.000` | confirmed the render was RT64 Resolution::Original (1x); default changed to Auto → `resolutionScale=7.000` (2240×1680), steady 60fps, crisp output (commit `557d376`) |
| 2026-08-06 02:0x | iPad Pro 11" (M4) Sim | settings sheet build (volume/resolution/aspect/layout) | builds and launches clean; the C bridge (PaperPad_SetAudioVolume/SetGraphicsConfig) applies saved settings at startup |
| 2026-08-06 02:0x | iPad Pro 11" (M4) Sim | agent-driven playthrough via Simulator hardware-keyboard forwarding (osascript key codes; Return=START, Z=A) | **full flow verified**: title screen -> storybook -> name entry (File 1 "First Play" created) -> file select -> "Start Game with File 1?" -> **Mario's House gameplay** ("Mail call!" dialogue advancing; health t=690+ at 60fps). Evidence: `docs/evidence/ipad-fileselect.jpg`, `docs/evidence/ipad-gameplay-marios-house.jpg` |
| 2026-08-06 02:1x | iPad Pro 11" (M4) Sim | audio output probe (SDL queue size added to health log) | `queued=2240..4704` bytes every tick — HLE audio mix reaches the SDL device queue (end-to-end audio path confirmed) |
| 2026-08-06 04:0x | iPad Pro 11" (M4) Sim | video capture + frame analysis (brightness at 30fps sampling) | **screen flashing reproduced and root-caused**: 253 full/partial alternations per 32s during the storybook. The present created between Paper Mario's two gfx tasks (background + main) drew the half-built starfield. |
| 2026-08-06 04:5x | iPad Pro 11" (M4) Sim | fix: present waits for the frame's main task (odd workload id + early notify + 16ms bound); runtime presents at the game's frame cadence | **flashing eliminated**: 4 changes/55s (all intended storybook page transitions), gfx steady 60fps, no pipeline stall. |
| 2026-08-06 07:30 | macOS | clean launch to verify the frame-boundary present; process crashed 37s in | **NEW crash root-caused**: `SIGBUS` in `save_read` at file select on an empty flash card — `filemenu_init -> fio_load_game -> fio_read_flash -> osFlashReadArray_recomp -> save_read`, fault addr `0x9db4c4000` = `save_buffer.data() + 0xFFFFC000` (slot `-1` read wraps to a huge offset). Crash log: `~/Library/Logs/DiagnosticReports/PaperPad-2026-08-06-073051.ips` (procLaunch 07:30:07). |
| 2026-08-06 07:44 | macOS | fix applied: `flash_page_offset` masks page_num to the chip's page count (patch `patches/mstan-n64modernruntime/flash-page-wrap.patch`); rebuild + launch with stderr log | **empty-slot flash read no longer crashes**: game booted, START at title, storybook played, new game created, and reached Mario's House gameplay (screenshots `/tmp/pp-fs1..3.png`); no crash logs after 07:30. |
| 2026-08-06 07:5x | iPad Pro 11" (M4) Sim | screenshot burst (40 shots, ~1s apart) during the intro cutscene on the previous build | **flashing reproduced despite the earlier fix**: 6/40 frames were the identical stale sanctuary frame (mean brightness exactly 0.1818 every time) interleaved with the progressing cutscene — the retrace present still landed mid-frame and timed out its 16ms wait. |
| 2026-08-06 08:0x | iPad Pro 11" (M4) Sim | final fix: REMOVED the VI-thread retrace present; only the swap-task present remains (`RT64_PRESENT_LOG`, `RT64_FLAG_LOG` console) | **exactly one present per frame, always after the swap task** (`[task] flags=0x4` -> one `[present]`, workload ids even, fb cycling 0x38F800/0x3B5000/0x3DA800); no odd-id or double presents. |
| 2026-08-06 08:0x | iPad Pro 11" (M4) Sim | screenshot bursts (45+45 frames) through logos -> intro -> storybook on the fixed build | **no repeated/identical frames** (previous build had 6/40 identical 0.1818 frames); dark frames are the storybook's own pages, each unique; brightness changes smoothly (0.17-0.57) with the cutscene; health log steady (gfx +104-120/2s). |
| 2026-08-06 08:1x | macOS | same fixed build, `RT64_PRESENT_LOG=1` launch | identical clean pattern: one present per frame at the swap boundary, no mid-frame presents. |
| 2026-08-06 08:1x | iPhone 16 Pro Sim | fixed build install + `simctl launch --console-pty` (`RT64_PRESENT_LOG`/`RT64_FLAG_LOG`) + 40-shot screenshot burst through the intro storybook | same clean pattern (one present per frame at the swap task, even workload ids); burst brightness drifts smoothly between scene plateaus (0.182-0.199-0.267) with no oscillation or identical repeat frames; dark frames are the storybook's own pages (`docs/evidence/iphone-flash-fixed-storybook.jpg`); health log steady (gfx +81-115/2s during the cutscene, audio +120). |
| 2026-08-06 09:1x | macOS | NSZombieEnabled run to identify the teardown crash object | **root cause found**: `-[AGXG13GFamilyBlitContext release]: message sent to deallocated instance` — the blit encoder (and later the resolve compute encoder, a texture descriptor in `MetalBufferFormattedView`, and `MetalShader::functionName`) were over-released: created via autoreleased class factories but explicitly released, leaving dangling pointers in the autorelease pool that crashed the next pool pop. |
| 2026-08-06 09:2x | macOS | fixes applied: retain() on blit/resolve encoders, drop releases of autoreleased descriptors/strings, unowned command buffer no longer released, thread-wide autorelease pool markers on all RT64 worker threads, `Application::~Application` stops/joins workers before member teardown | **teardown crash eliminated**: 8 consecutive SIGTERM cycles exit cleanly, a 110s run is stable and exits cleanly, zero crash reports; title screen renders correctly (`/tmp/ppdiag/fix7-render5.png`). |
| 2026-08-06 09:4x | iPad Pro 11" (M4) Sim | fixed build install + launch 25s + screenshot + terminate | renders the storybook opening ("Far, far away, beyond the sky") with the touch overlay; terminate produces no crash report. |

## Crash-log capture

macOS and iOS Simulator crashes are archived with
`scripts/capture-crashes.sh` (copies `~/Library/Logs/DiagnosticReports/PaperPad-*.ips`
into `logs/crashes/` and prints a one-line summary: exception, signal,
faulting thread, top frames). Run it after any launch/playtest that crashes.
22+ reports archived 2026-08-05:

- ~18: teardown `objc_autoreleasePoolPop` → `objc_release` in RT64 worker
  threads (process exit; game already ran).
- 2026-08-05 22:39: `SIGSEGV` in `load_asset_by_name` (stale pre-hardening
  binary hook; see table entry above).
- 1: `SIGBUS` in `create_audio_system_obfuscated` → `boot_main` (16:50, macOS
  era before the playable milestone; not reproduced since).
- 2: black-screen-era crashes (15:27 `CocoaWindow::updateRefreshRateInternal`
  on the main thread; 15:40 abort) — predate the `SDL_ShowWindow` fix.

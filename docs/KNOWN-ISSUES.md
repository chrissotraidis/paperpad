# PaperPad known issues and investigation archive

The detailed entries below preserve the 2026-08-05 through 2026-08-06 failure
investigations and fixes. They are historical evidence, not the current release
status. See `docs/STATUS.md` for the 2026-08-14 acceptance boundary and open
gates. Entries marked fixed are expected to remain covered by the pinned ReCut
snapshot or the maintained patch series.

Current audio note: on 2026-08-12 PaperPad generated and selected Paper Mario's
exact audio RSP entry at IMEM `0x1080` and preserved synchronous SP completion
ordering. The next physical-iPad listening route reported no crackle. This
supersedes the archive's older HLE-only implementation direction, but is one
hands-on route rather than a full-game audio acceptance pass.

Current crash note: the first physical cursor candidate correctly aligned the
battle hand, but crashed after the first Goomba died on two consecutive runs.
Both 2026-08-12 reports identify the temporary VI-thread battle diagnostic at
the same HUD-pointer load while battle objects were being released. The
diagnostic was removed without changing the projection fix; replacement binary
`670ef740…` then completed the same battle once without crashing. This was a
PaperPad instrumentation defect, not evidence that the US 1.0 game logic or
the projection hook failed.

Current progression note: the next physical run reproduced an abnormally slow
Goompa gate opening and then stalled after Mario crossed, with dialogue and
control still locked. The app, audio callbacks, and input logging continued.
The first safe logger was ineffective because generated direct calls bypassed
the overlay replacement. Diagnostic binary `5462f680…` instead observes the
actual generated `step_game_loop` and `NpcMoveTo` return boundaries on the game
thread. It changes no movement/script state and is installed for the next
route. The cause remains open until that trace is captured; no timeout or
scene-specific progression bypass is justified.

The next 2026-08-13 physical replay did not reproduce the failure. QuickTime
captured the route locally, and the matching diagnostic log shows every
observed `NpcMoveTo` returning success before `EVS_ReturnToVillage` reached the
normal badge-tutorial `SpeakToPlayer` wait. This rules out an unconditional
movement translation bug but does not erase the earlier stalls. Treat the issue
as intermittent until two additional complete physical routes pass or a marked
failure provides a contrasting trace.

## macOS

1. **Audio RSP microcode errors (FIXED 2026-08-05 23:40 via HLE audio)** —
   "RSP ucode 2 exited unexpectedly.
   exit_reason: 3" plus "Unhandled jump target 0x0000/0xFFFFF000" dumps in
   `n_aspMain` during the audio boot sequence. The game still advances
   (ultramodern's `run_rsp_task_or_warn` drops the failed task and signals SP
   completion), but the stderr flood slows startup and audio is unverified.
   Recurrence varies by run (0–3500 errors); a fresh 2026-08-05 rebuild
   reproduced 1677 errors while the game kept rendering.

   Status 2026-08-05 21:30: with the local runtime patches the flood still
   occurs but the game now plays the intro for 1-3 minutes; the audio ucode
   (n_aspMain) grinds/stalls on a per-task basis (DMA copies crawl at
   ~200 bytes/sec when the game starts freezing), which is downstream of the
   scheduler deadlock below rather than the root cause.

   **Root cause, corrected 2026-08-11**: the generated `n_aspMain` function is
   not a standalone replacement for the complete RSP task path. It starts with
   scalar registers cleared, but the real audio microcode assumes its boot
   microcode has already populated registers and DMEM before transferring
   control. Current RSPRecomp output still produced `Unhandled jump target
   0x0000` at the first audio task with `$26/$25/$29 = 0`. A bounded experiment
   that supplied the ABI table and seeded `$29` merely changed the first bad
   target to `0x0001`, while `$26/$25` still lacked the boot-supplied command
   state. That proves the old single-register diagnosis was incomplete. A
   correct non-HLE replacement must execute or faithfully reproduce the whole
   audio RSP boot contract; isolated register seeds are rejected.

   **Fix (applied, uncommitted in `ref/`)**: restore the upstream HLE path —
   `recomp::rsp::run_task` branches `M_AUDTASK` to a new
   `run_hle_audio_task` that copies the OSTask to DMEM[0xFC0] and calls
   `alist_process_naudio`. HLE sources (`alist.c`, `alist_naudio.c`,
   `audio.c`, `memory.c`) are built into `librecomp` from the vendored
   `ref/mupen64plus-rsp-hle`. Patch file:
   `patches/mstan-n64modernruntime/hle-audio-rsp.patch`. Result: no flood,
   audio tasks complete every frame, intro/story/gameplay verified on macOS
   and iPhone Simulator. Physical-iPad listening subsequently confirmed
   intermittent flutter/static, so HLE is functional but not release-quality.

   **Fresh physical evidence 2026-08-11 15:59**: the 82,919-byte current
   device log captured while the defect was audible held roughly 16–64 ms of
   queued 48 kHz output after sampled submissions, reported zero conversion
   errors, zero queue errors, no interval above 100 ms, and sub-full-scale PCM.
   This rules out output clipping and unbounded cache growth, but the sampled
   post-submit value cannot exclude a brief queue drain between submissions.
   Do not mask the defect with another unmeasured buffer, gain, or filter
   change; measure the pre-submit minimum and zero-queue count first.

   Follow-up: integrate and validate a complete boot+audio RSP implementation,
   such as an iOS-capable ParaLLEl-RSP path, then compare bounded PCM and
   physical listening against HLE. Do not re-enable standalone `n_aspMain` or
   treat a generated switch-table edit as a complete fix.

2. **Teardown autorelease crash (FIXED 2026-08-06)** — RT64 Workload worker
   threads crashed in `objc_autoreleasePoolPop` → `objc_release` on dangling
   pointers when the process exited (and, with per-frame pools added, during
   normal operation). Root cause: several Metal-cpp objects were over-released
   — the release counts went through the caller's autorelease pool as well as
   an explicit `release()`, leaving a dangling pointer that crashed the next
   pool pop. Identified with `NSZombieEnabled`:
   - `AGXG13GFamilyBlitContext` (blit encoder): `checkActiveBlitEncoder`
     created the encoder (autoreleased) without the `retain()` that
     `checkActiveRenderEncoder`/`checkActiveComputeEncoder` use, then
     `endActiveBlitEncoder` released it.
   - `AGXG13GFamilyComputeContext` (resolve compute encoder): same missing
     retain in `checkActiveResolveTextureComputeEncoder`.
   - `MTLTextureDescriptorInternal`: `MetalBufferFormattedView` released a
     descriptor from the autoreleased class factory `textureBufferDescriptor`.
   - `__NSCFString`: `MetalShader::~MetalShader` released `functionName`
     (from autoreleased `NS::String::string`).
   Also fixed: `MetalCommandList::commit()` no longer releases the unowned
   `commandBufferWithUnretainedReferences()` buffer (the frame's autorelease
   pool owns it). Each RT64 worker thread (Workload, Idle, Present, Buffer,
   Shader, Stream, Texture) now runs inside a thread-wide autorelease pool
   marker that is popped at loop end, and `Application::~Application`
   stops/joins the workload and present queues before any render objects are
   destroyed (they were previously torn down in reverse member order while
   the workers could still be encoding a frame).
   Patch: `patches/mstan-rt64/metal-worker-autorelease-and-overrelease-fixes.patch`.
   Verified 2026-08-06: 8 consecutive macOS SIGTERM cycles + a 110s run all
   exit cleanly with zero crash reports; iPad Simulator launch → 25s run →
   terminate produces no crash either. The game renders normally (title
   screen and storybook verified on macOS and iPad).

3. **Background launch quirk** — launching the raw binary from a terminal can
   trigger SDL_QUIT when the session's process group ends. Launching via
   `open PaperPad.app` behaves properly.

4. **No touch controls on macOS** — the touch overlay is an iOS feature;
   macOS uses keyboard/gamepad.

5. **Intro freezes at the intro map load (FIXED 2026-08-05 23:40, see #1)** —
   the game plays the N64 logo, star scene, and first story cutscene at
   ~60fps for about 2 minutes (sgl count ~3300-3600), then freezes
   deterministically at the intro's map/scene load (the star sanctuary map
   after the title screen). Evidence: the retrace broadcasts keep firing
   after the freeze (the host pump keeps the chain alive), but `step_game_loop`
   stops being called, so the game-side load is the blocker.

   Local runtime patches that substantially help (applied in
   `ref/mstan-n64modernruntime`, not committed):
   - `scheduler_tick.cpp`: the monitor thread now drains one pending external
     message per 50ms tick only when the game is genuinely stuck (no game-thread
     context switch for 200ms), writing it directly into the guest queue and
     waking the first blocked receiver. This keeps the app alive (no more
     SIGBUS from host-thread scheduler races) and extends the intro from ~40s
     to ~2 minutes, but does not unblock the map-load stall.
   - `mesgqueue.cpp`: `ultramodern_deliver_external_message_host` performs the
     pump's delivery without racing the cooperative scheduler's running queue
     (safe because it only runs when every game thread is parked).

   Failed approaches this session:
   - Direct host-side `schedule_running_thread` + semaphore signal on every
     pump tick corrupted the running queue (SIGBUS at a garbage thread
     pointer, KERN_PROTECTION_FAILURE at 0x380000004) — reverted.
   - Making `run_next_thread` wait on the external queue instead of throwing
     caused the same queue corruption under load — reverted.
   - Dropping audio RSP tasks (`PAPERPAD_DROP_AUDIO_RSP=1`) removes the audio
     ucode grind but the game stalls EARLIER (at the N64 logo) — the audio
     subsystem is load-bearing for the intro progression.

   Refined analysis (2026-08-05 23:00): the DMA copies are FAST (the game's
   `dma_copy` completes in microseconds, including a 197KB map asset). The
   intro map load succeeds: the asset searches resolve correct names
   (`hos_05_shape`, `hos_bg`, `hos_05_hit`), the scripts start with valid
   pointers, and `does_script_exist(mainScriptID)` keeps returning true. The
   freeze is the intro's own wait logic: `state_intro.c` `INTRO_AWAIT_MAIN`
   waits while the map's main script exists, and the main script
   (`EVS_Main` for `hos_05`, entry 3) blocks in
   `ExecWait(N(EVS_SetupMusic))`/`Exec(N(EVS_Scene_IntroStory))` — the
   intro cutscene's music/sound-dependent commands. With the audio RSP ucode
   broken (the `n_aspMain` error flood), the audio events the cutscene waits
   for never fire, so the script never completes and the intro waits forever.

   Fix direction: repair the audio path (make the recompiled audio ucode
   actually produce/complete audio tasks) OR make the audio-dependent waits
   non-blocking when audio is unavailable. `PAPERPAD_DROP_AUDIO_RSP=1`
   removes the flood but stalls the boot earlier (the N64 logo also waits on
   audio) — a working audio emulation is load-bearing for the intro.

   **Resolution 2026-08-05 23:40**: the HLE audio backend (see macOS #1)
   makes audio tasks complete, so the cutscene scripts finish, `EVS_Main`
   returns, `INTRO_AWAIT_MAIN` advances, and the game proceeds through the
   story into Toad Town gameplay. Verified: macOS `health.log` t=1348 (22+
   min) stable; iPhone Simulator t=450 (7.5+ min) stable. The freeze
   mechanism (SP Task Thread parked inside the ucode → `sp_complete` never
   fires → all game threads park) is preserved in this issue for reference;
   the `[freeze]` health-log dump can still capture any future recurrence.

6. **macOS launch hung in SDL_ShowWindow (fixed)** — the app linked Homebrew's
   `sdl2-compat` 2.32.70 (an SDL3 shim), which hung in
   `SDL_CreateWindow → SDL_ShowWindow → Cocoa_ShowWindow → SDL_RestoreWindow`.
   Fixed by building the vendored SDL2 2.32.10 static (`build-macos-sdl2/`)
   and linking it for the macOS target (same source as the iOS static build).

## Cross-cutting

- The pmret decomp requires a macOS host setup (venv, GNU cpp, MIPS
  toolchain); see `docs/BUILDING.md`.
- Ref/ROM and generated AOT output are gitignored and local-only.

## iOS (Simulator)

1. **Boot freezes mid-intro (FIXED by HLE audio, see macOS #1)** — reproduced
   4× on iPhone
   16 Pro Simulator (2026-08-05 17:53–18:05). The audio RSP task flood
   ("RSP ucode 2 exited unexpectedly. exit_reason: 3" = UnhandledJumpTarget
   in `generated/aot/rsp/n_aspMain.cpp`) never clears: `n_aspMain_impl` parks
   at +1152 (the PC 0x10EC dispatch/watchdog loop) and never returns, so
   `recomp::rsp::run_task` never returns false and ultramodern's graceful
   drop path (`run_rsp_task_or_warn` → `sp_complete`) never fires. All game
   threads end up parked in kernel waits (sample: `/tmp/pp-sample.txt`);
   gfx `send_dl` stops at count 1201; game time frozen. macOS runs the same
   generated ucode but the task exits, so the drop path triggers and the game
   continues — the behavioral difference is unresolved.

   Reproduce: `xcrun simctl launch <udid> com.chrissotraidis.paperpad`, wait
   60 s, observe the intro freeze at the gold/red star-spawn frame; console
   shows the RSP flood continuing while `[gfx] send_dl` stops increasing.

   Candidate fixes to try next:
   - Make the audio task path return when the ucode cannot process the current
     command stream (e.g., treat repeated UnhandledJumpTarget as task
     completion so the game's audio manager can move on), or
   - investigate why `n_aspMain` fails to exit on iOS specifically (thread
     scheduling under the simulator, DMEM/task state differences), or
   - gate the audio ucode behind a flag so boot proceeds silently until the
     microcode mismatch is fixed.

   **Resolution 2026-08-05 23:40**: with HLE audio, the iPhone Simulator run
   completes the intro story and loads Toad Town gameplay assets (health
   log stable to t=450). One stall at t≈256 (2026-08-05 23:31) did not
   reproduce on two subsequent runs; treat as intermittent until it
   reproduces on a clean boot. The `[freeze]` diagnostic in the health
   logger (guest `startupState`/`introPart`/`mainScriptID` + message-log
   tail) will capture the blocking wait if it returns.

2. **Drawable sized in points, not pixels** — RT64's MetalSwapChain drawable
   is 874×402 @ contentsScale 1.0 (iPhone 16 Pro) instead of 2622×1206;
   renders correctly but soft. `resize()` does not appear to apply native
   scale on iOS. Cosmetic; verify after the boot-stall fix.

2b. **iPad ran in iPhone-compatibility mode (FIXED 2026-08-06)** — the app
    built with `UIDeviceFamily=[1]` (iPhone-only), so iPadOS launched it in
    compatibility mode: an iPhone-sized 667×375 window centered in the iPad
    screen (with the floating "2x" control), and the game rendered
    zoomed/cropped inside it. Root cause: CMake's iOS target defaulted the
    device family to 1; `LSRequiresIPhoneOS` was also set. Fixed by removing
    `LSRequiresIPhoneOS` from `Info.plist.in` and setting
    `XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"` on the PaperPad target
    (commit `eca833c`). Window diagnostics now log
    `UIScreen.bounds/currentMode/nativeBounds` to catch regressions.

3. **Game rendered zoomed/cropped on iOS (FIXED 2026-08-06)** — the visible
   game frame showed only the top-left ~half (e.g. the PAPER MARIO title
   sign cut to "PA"/"MA"). Root cause: RT64's iOS `CocoaWindow` reports the
   swapchain size in PIXELS (window points × nativeScale = 2420×1668 on the
   iPad), but SDL leaves the CAMetalLayer at `contentsScale 1.0`, so the
   actual drawable was point-sized (1210×834). The present viewport math is
   sized for the pixel surface and the GPU clipped the frame to the smaller
   drawable — a 2x zoom with the right/bottom cropped. Diagnosed with a
   runtime render probe (`[render] swapchain=2420x1668 vs drawable=1210x834`).
   Fix (commit `0ab64ce`): `paperpad_fix_metal_layer_scale` sets the layer's
   `contentsScale` to the screen's nativeScale and `drawableSize` to
   bounds × nativeScale after the Metal view is created. Verified: diag
   shows `drawable=2420x1668 @ contentsScale 2.00` and the title screen
   renders in full (`docs/evidence/ipad-title-full.jpg`).

4. **Game rendered soft/shimmering at 1x internal resolution (FIXED
   2026-08-06)** — the graphics config defaulted to RT64 `Resolution::Original`
   (1x), so the native 320x240 frame was upscaled ~7.5x to the iPad's
   2420x1668 drawable — visibly soft, and the moving image shimmered (this is
   the "screen flashing / performance" the user saw on a live Simulator).
   Diagnosed with the render probe (`userConfig.resolution=0 resolutionScale=
   1.000`). Fix (commit `557d376`): default the graphics config to
   `Resolution::Auto` (WindowIntegerScale) unless the iOS settings sheet has a
   saved preference; the render now runs at 7x (2240x1680) with steady 60fps.
   The settings sheet originally offered Auto/2x resolution and now offers
   Auto plus fixed 1x/2x/3x/4x choices; Original/Expand aspect remains
   separate. The 2026-08-10 final iPad and iPhone Simulator passes exercised
   every scale by touch, confirmed the renderer mode/multiplier in the private
   session log, and observed no new visual defect on the opening routes. Longer
   gameplay and physical-device scale acceptance remain open.

5. **Screen flashed full/partial frames during 30fps cutscenes (FIXED
   2026-08-06, final fix)** — the visible image alternated between the
   complete scene and a stale/half-built framebuffer (the bare star
   sanctuary, exactly 0.1818 mean brightness, re-appearing every few seconds
   during the intro cutscene). Root cause: two independent present paths
   fired per frame — the VI-thread retrace present (at the guest frame
   cadence) and the gfx-thread present after the swap task. The retrace
   present could land BETWEEN Paper Mario's two gfx tasks per frame (the
   background task and the main swap task), and the RT64 present queue's
   16ms bounded wait for the main task could time out on slow frames, so the
   half-built background was drawn to the display.

   Final fix: the VI-thread retrace present was REMOVED entirely; the only
   present now fires at the swap-task boundary (`flags & 0x4`,
   `NU_SC_SWAPBUFFER`) — the exact moment a frame's RDP completes — so a
   present can never land mid-frame. Every Paper Mario frame ends with a
   swap task (verified across boot logos, intro cutscene, and menus), so no
   present is ever missed. The RT64 odd-workload wait patch remains as a
   defensive bound but is no longer on the hot path.
   Patches: `patches/mstan-rt64/present-wait-workload.patch`,
   `patches/mstan-n64modernruntime/vi-screen-update-cadence.patch` (removed
   the retrace present). Verified 2026-08-06 on iPad and macOS:
   `RT64_PRESENT_LOG` shows exactly one present per frame at the swap task,
   and two screenshot bursts (45 frames each) through the logos → intro →
   storybook show NO repeated/identical frames (previously 6/40 samples were
   the identical 0.1818 stale frame); dark frames in the new bursts are the
   storybook's own dark pages, each unique, and brightness changes smoothly
   with the cutscene. gfx stays at 60fps.

6. **Crash at the file-select screen on an empty flash card (FIXED
   2026-08-06)** — a fresh macOS/iOS install crashed with SIGBUS in
   `save_read` (`EXC_BAD_ACCESS KERN_PROTECTION_FAILURE` at a wild address)
   every time the game reached the file-select screen with no saved games.
   Stack: `state_step_file_select -> filemenu_init -> fio_load_game ->
   fio_read_flash -> osFlashReadArray_recomp -> save_read`. Root cause:
   `filemenu_init` calls `fio_load_game(i)` for every slot; on an empty card
   `LogicalSaveInfo[i].slot == -1`, so the game calls
   `osFlashReadArray(page_num = -1 * 128)` and the real flash chip ignores
   the high address bits (the SDK multiplies the page index by 0x80 into a
   32-bit byte offset that wraps). The host flash recomp functions indexed
   the flat 128 KiB save buffer with the un-wrapped offset, reading far out
   of bounds. Fix (`patches/mstan-n64modernruntime/flash-page-wrap.patch`):
   `flash_page_offset(page_num)` masks the page number to
   `page_count - 1` (1023), matching the chip's address decode, so the
   out-of-range read wraps into erased (0xFF) flash and the game's checksum
   validation fails gracefully (empty slot). Also clamps read length to the
   flash end. Verified: macOS boots → title → file select → new-game
   creation → Mario's House gameplay without crashing (previously crashed
   37s after launch, every time). The crash log is
   `~/Library/Logs/DiagnosticReports/PaperPad-2026-08-06-073051.ips`.

7. **File 1A transition shudder and SimMetalHost crash under runaway memory
   pressure (FIXED 2026-08-10)** — the reported 4x iPad Simulator run grew
   from roughly 744 MiB RSS at 32 seconds to 8.77 GiB at 8:14, destabilized
   ScreenCaptureKit/CoreSimulator, and ended with Metal termination namespace
   102 after SimMetalHost disappeared. A 1x comparison had nearly the same
   slope, so resolution size was not the primary leak. Metal-cpp convenience
   methods returned autoreleased serializer wrappers on long-lived RT64 and
   N64ModernRuntime threads whose outer pools drained only at shutdown.

   The retained fix drains display-list and screen-update callbacks, presents,
   fence-completed idle work, and fully synchronized texture-upload batches.
   A broader workload pool was explicitly rejected after it reproduced a
   SimMetalHost deserializer resource-map crash. On the retained build, File 1A
   reached “Mail call!” and Mario's House at 4x; physical footprint held
   124.0→124.6 MiB and VM allocation regions remained exactly 255 across a
   45-second idle comparison, then remained 255 after the house transition.
   Sampled transition frames showed the intended black/fade/scene sequence,
   not a stale or half-built framebuffer.

8. **Music played with severe block-boundary clipping (FIXED IN CODE
   2026-08-11; audible acceptance open)** — the earlier overlap-pointer repair
   fixed one indexing error but retained a stateless block converter. Bounded
   source/output PCM comparison showed that converter added high-frequency
   energy and doubled the worst step. PaperPad now keeps one continuous
   `SDL_AudioStream` and no longer shortens already-rendered PCM to catch up.
   Simulator output matched the source spectrum. The installed physical build
   then produced 190 telemetry windows with the expected 32→48 kHz frame ratio,
   a 60.75 ms maximum queue, no over-100 ms event, no conversion/queue error,
   and no block-boundary peak above its within-block peak. These measurements
   establish a clean structural path, but cannot prove subjective audible
   quality; human physical-device listening remains open.

9. **`CAMetalLayer` display-sync property changed off the main thread (FIXED
   2026-08-10)** — the clean reproduced launch logged UIKit's off-main-layer
   mutation assertion from RT64 setup. iOS `setVsyncEnabled` and
   `isVsyncEnabled` now marshal the layer access synchronously to the main
   queue when called from a renderer thread. The final log did not reproduce
   the warning.

10. **Metal drawables and Simulator FramePacing objects accumulated once per
    frame (FIXED 2026-08-11)** — a sustained level-27 Toad Town run grew from
    148.7 to 160.0 MiB physical footprint while RT64 `VM_ALLOCATE` regions
    stayed fixed at 255. Heap inspection found 42,354 live `CAMetalDrawable`,
    42,352 drawable-lifetime, and 757,314 `FPInFlightCommandBuffer` objects.
    `MetalSwapChain::acquireTexture` retained each replacement drawable but
    overwrote the swap-chain slot without releasing its previous retained
    owner; presentation's independent retain/release did not balance the slot.
    `patches/rt64/metal-drawable-slot-lifetime.patch` now retains the new
    drawable first, releases the old slot owner, assigns the replacement, and
    makes destruction null-safe. Clean patch replay and the rebuilt ROM-free
    app passed. Across thousands of post-fix frames, heap counts stayed exactly
    3 drawables, 3 lifetimes, and 72 FramePacing command buffers; physical
    footprint ended at 130.1 MiB below a 145.3 MiB peak.

11. **Simulator shutdown aborted while deallocating `CAMetalLayer` on the Gfx
    Thread (FIXED 2026-08-11)** — the user-supplied 12:22 iPhone report showed
    `CAMetalLayer dealloc` → `MetalSwapChain::~MetalSwapChain`; an isolated iPad
    shutdown reproduced the same abort at 12:32. RT64 treated
    `renderWindow.view` as owned and released it, but the layer is supplied and
    owned by SDL/UIKit. `patches/rt64/ios-metal-view-lifetime.patch` suppresses
    only that unowned iOS release and preserves macOS behavior. Rebuilt iPhone
    and iPad active-rendering shutdowns produced no newer crash report.

3. **simctl screenshots are portrait-framebuffer** — the app is landscape, but
   `simctl io screenshot` returns the portrait device framebuffer, so PNG
   evidence shows the game content bottom/right-anchored with black elsewhere.
   Capture the Simulator window instead (`screencapture` of the window region)
   for true landscape evidence.

4. **Touch attach was missing** — `paperpad_touch_attach` had no caller; the
   overlay never appeared. Fixed 2026-08-05 (call added in `create_window`).
   Verified visible in `docs/evidence/ios-iphone-touch-overlay.png`.

# PaperPad known issues

Updated 2026-08-05 23:55.

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

   **Root cause (2026-08-05 23:20, definitive)**: the recompiled `n_aspMain`
   ucode never sets its audio command pointer. In the real ucode, `$29`
   (the command pointer) is set to `0x2B0` in the delay slot of a `jr $5`
   inside a DMA subroutine at RSP offset `0x10A0`; that subroutine is dead
   code in the RSPRecomp output (no direct branch targets it and it is not in
   `extra_indirect_branch_targets`), so on every task the ucode runs with
   `$29 = 0` and reads DMEM[0..] — its own dispatch table — as the audio
   command list. That yields "Unhandled jump target 0x0000/0xFFFFF000"
   (dispatch table slots 12/14 = `0x1C84`/`0x02B0` are also missing from the
   generated switch, so even correct opcodes 0x0C/0x0E would fail), and
   occasionally a task enters an infinite DMA-copy spin inside the ucode
   (observed at `n_aspMain_impl +1132/+1152`; the SP Task Thread never
   returns, `sp_complete` never fires, all PM threads park — the freeze).
   The upstream N64ModernRuntime never runs this ucode: it routes `M_AUDTASK`
   through mupen64plus-rsp-hle (`alist_process_naudio`). The mstan fork
   replaced that path with the recompiled ucode, which regressed audio.

   **Fix (applied, uncommitted in `ref/`)**: restore the upstream HLE path —
   `recomp::rsp::run_task` branches `M_AUDTASK` to a new
   `run_hle_audio_task` that copies the OSTask to DMEM[0xFC0] and calls
   `alist_process_naudio`. HLE sources (`alist.c`, `alist_naudio.c`,
   `audio.c`, `memory.c`) are built into `librecomp` from the vendored
   `ref/mupen64plus-rsp-hle`. Patch file:
   `patches/mstan-n64modernruntime/hle-audio-rsp.patch`. Result: no flood,
   audio tasks complete every frame, intro/story/gameplay verified on macOS
   and iPhone Simulator. Audible output still needs a speaker/device check.

   Optional follow-up (NOT needed for playability): regenerate `n_aspMain`
   with `extra_indirect_branch_targets` including `0x1C84` and `0x02B0` (and
   verify the `$29` setup path) so the recompiled ucode could replace HLE.

2. **Teardown autorelease crash** — RT64 Workload/Present worker threads can
   crash in `objc_autoreleasePoolPop` when the process exits. This is a
   Metal-cpp lifecycle issue in the RT64 worker threads during Application
   teardown; gameplay is unaffected. Reproduced again 2026-08-05 18:15:21
   (`logs/crashes/PaperPad-2026-08-05-181521.ips`, faultingThread 24).
   Fix path: ensure per-thread autorelease pools are balanced before RT64
   worker loops exit.

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
   The settings sheet offers Auto/2x resolution and Original/Expand aspect.

5. **Screen flashed full/partial frames during 30fps cutscenes (FIXED
   2026-08-06)** — the visible image alternated between the complete scene
   and the half-built background (e.g. the storybook page vs the bare
   starfield) at ~30Hz. Root cause: Paper Mario builds each frame with two
   gfx tasks (a background task that also renders to a temp buffer, then the
   main task), and the VI retrace can fire between them. The RT64 present
   created mid-frame covered only the background workload and drew the
   half-built target. Fix (commit pending): the present, when its workload id
   is odd (mid-frame), notifies its present id early (so the frame's main
   task can proceed) and waits up to 16ms for the main task's workload before
   drawing. Also, the runtime's VI thread only emits screen updates at the
   game's own frame cadence (retrace-aligned) instead of a fixed 60Hz.
   Patches: `patches/mstan-rt64/present-wait-workload.patch`,
   `patches/mstan-n64modernruntime/vi-screen-update-cadence.patch`. Verified:
   frame-brightness analysis dropped from 253 changes/32s to 4 changes/55s
   (the remaining are intended storybook page transitions); gfx stays at
   60fps with no pipeline stall.

3. **simctl screenshots are portrait-framebuffer** — the app is landscape, but
   `simctl io screenshot` returns the portrait device framebuffer, so PNG
   evidence shows the game content bottom/right-anchored with black elsewhere.
   Capture the Simulator window instead (`screencapture` of the window region)
   for true landscape evidence.

4. **Touch attach was missing** — `paperpad_touch_attach` had no caller; the
   overlay never appeared. Fixed 2026-08-05 (call added in `create_window`).
   Verified visible in `docs/evidence/ios-iphone-touch-overlay.png`.

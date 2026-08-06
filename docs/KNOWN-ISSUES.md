# PaperPad known issues

Updated 2026-08-05 21:30.

## macOS

1. **Audio RSP microcode errors** — "RSP ucode 2 exited unexpectedly.
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

5. **Intro freezes at a scene transition (primary blocker, 2026-08-05)** —
   the game plays the N64 logo, star scene, and first story cutscene at
   ~60fps for 1-3 minutes, then freezes on a black/transition screen. Root
   cause (verified with instrumentation): the mstan runtime's cooperative
   scheduler deadlocks when every game thread parks in `osRecvMesg`
   (`do_recv` → `run_next_thread_and_wait` → host semaphore). The VI thread
   keeps posting retraces (60/s) into the runtime's external-message queue,
   but no game thread runs to drain/deliver them, so `nuScEventHandler`
   never receives a retrace, `gfxRetrace_Callback` stops calling
   `step_game_loop`, and the game freezes.

   Local runtime patches that substantially help (applied in
   `ref/mstan-n64modernruntime`, not committed):
   - `scheduler_tick.cpp`: the monitor thread now drains one pending external
     message per 50ms tick (the "pump"), so retraces/completions reach the
     guest queues even when all game threads are parked.
   - `mesgqueue.cpp`: `do_send` wakes a blocked receiver's host semaphore when
     the sender is a host thread (the pump), because the cooperative scheduler
     only does that handoff when a game thread runs it.
   - `threads.cpp`: `run_next_thread` waits on the external-message queue
     instead of throwing "No runnable threads remain" when the running queue
     is empty.

   Result: the game went from freezing at ~40s (N64 logo) to playing the intro
   for 1-3 minutes. The deadlock still re-triggers at the scene transition;
   the delivery now succeeds (do_send sent=1) but the game freezes shortly
   after, suggesting a secondary stall (asset DMA load, or the audio ucode
   grind starving the pump's wake) not yet root-caused.

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

1. **Boot freezes mid-intro (blocking gameplay)** — reproduced 4× on iPhone
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

2. **Drawable sized in points, not pixels** — RT64's MetalSwapChain drawable
   is 874×402 @ contentsScale 1.0 (iPhone 16 Pro) instead of 2622×1206;
   renders correctly but soft. `resize()` does not appear to apply native
   scale on iOS. Cosmetic; verify after the boot-stall fix.

3. **simctl screenshots are portrait-framebuffer** — the app is landscape, but
   `simctl io screenshot` returns the portrait device framebuffer, so PNG
   evidence shows the game content bottom/right-anchored with black elsewhere.
   Capture the Simulator window instead (`screencapture` of the window region)
   for true landscape evidence.

4. **Touch attach was missing** — `paperpad_touch_attach` had no caller; the
   overlay never appeared. Fixed 2026-08-05 (call added in `create_window`).
   Verified visible in `docs/evidence/ios-iphone-touch-overlay.png`.

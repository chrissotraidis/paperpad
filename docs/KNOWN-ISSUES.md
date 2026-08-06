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

5. **Intro freezes at the intro map load (primary blocker, 2026-08-05)** —
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

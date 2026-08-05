# PaperPad known issues

Updated 2026-08-05.

## macOS

1. **Audio RSP microcode errors** — "RSP ucode 2 exited unexpectedly.
   exit_reason: 3" plus occasional "Unhandled jump target" dumps during boot.
   The naudio ucode settles into its loop; audio output is not yet verified.
   Investigation: the extra indirect branch targets and DMEM setup for the
   audio task need a closer match to the runtime's RSPRecomp expectations.

2. **Teardown autorelease crash** — RT64 Workload/Present worker threads can
   crash in `objc_autoreleasePoolPop` when the process exits. This is a
   Metal-cpp lifecycle issue in the RT64 worker threads during Application
   teardown; gameplay is unaffected. Fix path: ensure per-thread autorelease
   pools are balanced before RT64 worker loops exit.

3. **Background launch quirk** — launching the raw binary from a terminal can
   trigger SDL_QUIT when the session's process group ends. Launching via
   `open PaperPad.app` behaves properly.

4. **No touch controls on macOS** — the touch overlay is an iOS feature;
   macOS uses keyboard/gamepad.

## Cross-cutting

- The pmret decomp requires a macOS host setup (venv, GNU cpp, MIPS
  toolchain); see `docs/BUILDING.md`.
- Ref/ROM and generated AOT output are gitignored and local-only.

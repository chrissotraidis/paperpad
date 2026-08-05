# PaperPad status

Updated 2026-08-05 (America/Chicago). Target-by-target status.

| Target | Status | Evidence |
|---|---|---|
| macOS native app | **Playable — boots and runs Paper Mario's intro** | Renders at 50–60fps; opening narration "way above the clouds," visible; `docs/evidence/macos-opening-scene.png` |
| iPhone Simulator | In progress (build pipeline ported; app shell pending) | — |
| iPad Simulator | In progress | — |
| iOS device (unsigned IPA) | Not started | — |
| Signed physical device | Blocked externally (no signing identity/device) | — |

## macOS current state

Works:
- Boots through decomp-verified AOT code, main-loop spin hooks, anti-piracy
  wrapper bypass, audio/RSP microcode, and RT64 Metal rendering.
- Renders the game window at 50–60fps and advances the intro scene.
- Keyboard input wired (Z=A, X=B, Enter=Start, arrows=stick, WASD=DPad).
- Logs runtime events to stderr for diagnosis.

Known issues (see `docs/KNOWN-ISSUES.md`):
- Audio RSP errors ("RSP ucode 2 exited unexpectedly") — mostly startup
  noise; audio playback not yet verified.
- Process teardown can crash in RT64 worker autorelease cleanup.
- No touch controls on macOS (keyboard/gamepad only).

## Next milestone

iPhone/iPad Simulator build of the same mstan runtime+RT64 stack with the
UIKit shell and Paper Mario touch controls.

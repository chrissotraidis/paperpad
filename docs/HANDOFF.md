# PaperPad handoff

Latest: 2026-08-05. See `STATUS.md` for the authoritative status table.

## What works

- Reference inputs cloned and pinned (SpaghettiPad, pmret decomp, ReCut).
- ROM present in `ref/`, verified as Paper Mario (U) US 1.0.
- Docs scaffold in place.

## What does not work yet

- Decomp ELF build, AOT generation, and every app target.

## Next highest-priority task

Build the pmret decomp ELF (Phase 1), then generate AOT source with
N64Recomp (Phase 2), unblocking the macOS app.

## How to reproduce current issues

Run the Phase 1 commands in `BUILDING.md`; log any failure under `logs/`.

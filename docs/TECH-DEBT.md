# PaperPad technical debt

Updated 2026-08-14 from hands-on testing of the physical iPad and iPhone development builds.
This is the morning triage list, not a claim that the causes below are already
known. The menu is usable and touch visibility, opacity, layout, and volume
controls feel good, but the exercised route is not yet release-accepted. The
battle pointer is physically verified; Goomba Village progression remains a
release blocker. Audio has one provisional
hands-on pass and must be reopened if it recurs.

### Latest longer-session and iPhone boundary (2026-08-13–14)

- The latest iPad/controller log covers 16m41s and 30,000 frames. It contains
  no crash, fatal/assert, or game-loop-stall line. The user judged the game
  good during this route.
- All 498 audio telemetry windows report zero conversion and queue errors. One
  mid-session queue-depth excursion exceeded 100 ms and then recovered; it is
  retained as regression evidence, not treated as an audible failure without
  a matching report.
- A Kishi V2 exercised analog plus A/B/Z/L/R/Start. D-pad, all C directions,
  controller disconnect/reconnect, and overlay restoration remain targeted
  acceptance checks rather than a reason to redesign the input path.
- The first grouped-layout iteration was rejected on the physical iPhone: its
  C cluster was too loose, its D-pad was too tight, and group movement was
  mandatory. `iphone.v8` corrects the phone-only geometry and restores
  individual movement by default. Link/Unlink optionally binds only the
  selected D-pad or C cluster and persists that choice. The accepted iPad
  `ipad.v4` defaults remain independent.
- A clean signed build is installed and running on the physical iPhone 14. The
  exact private iPad ROM and 128 KiB save were seeded before a clean in-place
  reinstall. Runtime output proves the clean app can initialize and enter the
  game, but File Select/save visibility and touch ergonomics need the user's
  direct iPhone acceptance.

The remaining release work is targeted: two Goompa route replays, iPhone
hands-on acceptance, complete controller mapping/reconnect checks, and a
longer/chapter-spanning route. Do not add speculative game-script work unless
the intermittent progression failure reproduces with a contrasting trace.

### Latest hands-on boundary (2026-08-12 13:37–15:27 Europe/Budapest)

- The user's latest listening pass reported that audio sounded fixed. The run
  used Paper Mario's newly generated exact audio RSP entry at IMEM `0x1080`,
  with synchronous SP completion ordering. Treat this as one physical-iPad
  pass; reopen immediately if flutter/static recurs in a longer route.
- The shared `get_screen_coords` replacement uses the US 1.0 projection math;
  it contains no battle- or actor-specific offset. The user confirmed on the
  physical iPad that the hand now aligns correctly with the selected Goomba.
- That first cursor candidate then crashed immediately after the first Goomba
  was defeated, twice. Both retained iPad reports (`15:00:30` and `15:01:35`)
  are identical `EXC_BAD_ACCESS`/`SIGBUS` failures on the VI Thread at
  `trace_vi_frame + 1744`. Disassembly maps the fault to the temporary
  diagnostic sampler dereferencing a HUD-element pointer while battle objects
  were being torn down. The projection hook is not in either crashing stack.
- The temporary cross-thread battle sampler has been removed. Goompa sampling
  now runs after the original game-loop step and validates guest pointers. The
  replacement ROM/save-free binary SHA-256
  `670ef7402545acd6ade482fb78c20d12133895d1b9adc37660d409870ffcaa6e`
  passed build, strict signature, and an in-place iPad install/launch. The next
  physical run completed the same first-Goomba battle without crashing. A
  second clean battle remains desirable regression evidence, but the
  deterministic instrumentation crash no longer reproduced.
- The same run reached the Goompa gate. The gate eventually opened, but only
  after an abnormally long delay; after Mario crossed, the characters remained
  idle and dialogue/progression did not resume. The live log was copied while
  PaperPad was still running. It shows continuing audio and input events, so
  this is a guest cutscene/script stall rather than a whole-app freeze.
- The first revised Goompa logger emitted no scene rows because generated
  functions call `step_game_loop` directly and bypass the runtime overlay
  lookup. That empty trace is not treated as diagnosis. The replacement uses
  maintained N64Recomp hooks at the actual `step_game_loop` and `NpcMoveTo`
  return boundaries. Both execute on the guest game thread and only observe
  original state/result values.
- The observation-only candidate executable SHA-256
  `5462f680e9a50af18451e1d2453c06503fffb3601a392c3c6903d55b5c04ea76`
  passed build and strict signing, contains no ROM/save, and installed in place.
  Exact pre/post save read-back remained byte-for-byte identical at SHA-256
  `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398`.
  Startup confirms the safe game-loop hook is active.
- A 2026-08-13 physical-iPad replay with a local unsaved QuickTime recording
  completed the previously failing return-to-village route. The corresponding
  log shows every observed `NpcMoveTo` returning success, including Goompa's
  approaches to `(-295,-30)`, `(-168,-15)`, and subsequent village positions.
  The script advanced into the normal badge tutorial and was waiting in
  `EVS_PromptForBadgeTutorial -> SpeakToPlayer`, not frozen. This rules out an
  unconditional `NpcMoveTo` translation defect. Because prior physical runs
  did stall, progression remains an intermittent release gate until two more
  complete passes reproduce this result.
- A direct source/generated-code comparison found no divergence in
  `NpcMoveTo` or `npc_move_heading`: the recomp resolves and retains the NPC,
  computes its goal, speed, yaw, and distance, advances it each call, and
  blocks until the remaining distance is within one movement step just like
  the US 1.0 decomp. That rules out the simplest static movement-translation
  hypothesis; the exact blocked script/API state must come from a reproduced
  gate run before any scene-specific change is justified.

Release remains blocked until two more instrumented Goompa return-to-village
routes complete with dialogue, movement, and input restored. A new failure
must be marked live and compared against the successful trace before any game-
behavior change is justified.

## 2026-08-12 targeted physical-iPad iteration

The user re-ran File 1 on the physical iPad. Intermittent music static remained
audible, and the battle selection hand was still horizontally detached from
the selected Goomba. The user did not replay the Goompa gate sequence during
this pass, so the progression guard remains unaccepted. These results keep the
build release-blocked.

### What was tried, and what the evidence now says

- The earlier continuous `SDL_AudioStream` conversion repair removed a measured
  block-boundary resampling defect, but did not remove all audible static.
- An earlier uninstrumented increase from 1.5 to 2.5 VI frames did not
  eliminate the physical-device symptom and was reverted. That run predated
  both host-queue feedback and synchronous audio-task ordering, so it did not
  test the current pipeline.
- SDL telemetry remained structurally healthy while the user heard static:
  callbacks stayed near 20–23 ms, queued output remained bounded after each
  submission, and no conversion or queue errors were recorded. The existing
  counter does not prove the device queue stayed non-empty between submissions,
  so output starvation was not ruled out. A new pre-submit counter then proved
  the 1.5-VI candidate reached an empty device queue 2–7 times in every
  two-second window, including after music began. This is a real underrun
  signature that the old post-submit counter concealed.
- Source comparison found a second, independent audio clock in the pinned
  runtime: `osAiGetLength` reported a synthetic wall-clock two-entry N64 FIFO
  instead of the actual host audio queue used by SDL. The 2026-08-12 candidate
  removes that duplicate model and uses the official runtime's host-queue
  feedback seam. This changes pacing, not volume, filtering, or ROM data.
- A wider scheduler audit then found that graphics and audio tasks posted
  indistinguishable completion messages to Paper Mario's one guest SP queue
  from two host threads. That ordering can let the guest recycle a small audio
  command buffer while the host audio task is still consuming it. The current
  candidate executes each small audio task synchronously before posting its SP
  completion, preserving the single-RSP ordering the game expects. This is a
  runtime scheduling correction, not a ROM, save, or generated-game-code edit;
  physical listening still determines whether it closes the static.
- With those two runtime corrections active, one bounded 1.5→2.5-VI A/B on
  the same physical iPad removed every post-startup drain: 36 consecutive
  two-second windows reported zero empty or under-5-ms pre-submit queues,
  minimum headroom stayed 8.5–13.2 ms, and peak queued output stayed bounded
  below 73 ms. The 2.5-VI value is therefore retained as a measured starvation
  repair, not a cache-size guess. It still needs hands-on listening because
  counters cannot establish audible quality.
- The pointer remained wrong while the renderer reported Original 4:3
  (`aspect=Original`, `fill=0`). This disproves the earlier claim that Fill
  Screen's expanded projection was the complete cause. No global or
  actor-specific pointer offset has been added.
- Recompiled functions call one another directly within generated translation
  units, so an overlay lookup hook cannot reliably observe either target draw
  or Goompa movement. That dead hook path was removed. The current candidate
  samples the same read-only target, camera, HUD, NPC, and input-lock fields at
  the stable VI boundary. It cannot move a pointer or NPC and should finally
  provide useful evidence from a short first battle and the Goompa scene.

The current signed candidate executable has SHA-256
`568193f74616de7d01fa4d3794a5bcbe5e0ab15195bfa485a49921db04bfe837`.
It was installed in place and launched on the physical iPad without removing
PaperPad or replacing its data container. Startup diagnostics confirm the new
binary reached renderer/game/audio initialization and activated synchronous
audio-task ordering. Its preserved save hash was identical immediately before
and after installation. Audible quality, pointer alignment, and Goompa
progression still require hands-on acceptance; a successful build and healthy
queue counters do not close any of those issues.

The user's 10:39 hands-on report was produced before this exact candidate was
installed. The current candidate is the first one that combines host-queue
feedback, synchronous audio-task ordering, retained 2.5-VI headroom, and the
pre-submit drain counter. It still needs human listening, and its battle and
Goompa diagnostics need those exact routes before they can identify either
gameplay defect.

An earlier candidate contained a scene-specific two-second Goompa movement
completion guard. Review rejected that approach before acceptance: it wrote an
NPC position and returned completion without proving why the original movement
stalled. The installed hash above removes that behavior. Its Goompa hook is
diagnostic-only and cannot change NPC, script, story, or input-lock state.

### Next evidence gate

1. From File 1, enter the first target-selection screen once and record whether
   the hand remains horizontally wrong. Extract the resulting bounded current
   log and compare the selected target's true position, projected screen
   coordinate, and HUD render position before changing code.
2. During the same short route, listen for the previously repeatable static.
   If it remains, capture its approximate timestamp and correlate it with
   source PCM discontinuity and AI queue-feedback values. Do not add latency or
   gain changes without evidence.
3. Separately, reproduce the Goompa sequence from the preserved save three
   times. The narrow guard is accepted only if the original scene completes,
   control returns, and diagnostics show the exact stalled `NpcMoveTo` goal;
   it must not become a general scene-skip mechanism.

## 2026-08-11 16:02 physical-iPad progression blocker

The installed physical build reached the Goomba Village gate-unlock sequence,
where Goompa approaches to advance the scene. The sequence stalled: Mario,
Goompa, and the nearby Goombas remained standing in place; movement and NPC
interaction were unavailable; and Start initially did not respond. Start
eventually registered, but normal control and scene progression did not return.
The supplied screenshot records Mario and Goompa partly obscured behind the
front fence while the surrounding actors remain idle. This is a P0 game-
progression failure, not a cosmetic issue.

The cause is not yet established. The screenshot alone does not prove an input
failure, script deadlock, audio wait, renderer problem, or bad save state.
Preserve the current save and diagnostics before attempting a fix; do not add a
scene-specific skip or force-clear player input.

### Next-iteration reproduction and acceptance

1. Start from a known save before the Goomba Village gate-unlock sequence and
   retain a copy of the exact pre-scene save plus current/previous diagnostics.
2. Reproduce three clean runs without overwriting File 1. Record whether the
   cutscene actor, dialogue, camera, music, and input-lock state each advance.
3. Inspect the guest script/thread/message state at the first frozen frame and
   identify the actual wait condition before changing scheduler, input, or
   audio behavior.
4. Acceptance requires the sequence to complete in all three runs, restore
   analog movement, accept Start promptly, and allow conversation with nearby
   NPCs. Save/relaunch must continue past the scene without corrupting either
   file slot.

## 2026-08-11 14:33–14:52 physical-iPad review

The latest hands-on route adds the following evidence and corrections. These
rows supersede any earlier claim that selecting a setting was enough to prove
its visual effect.

| Finding | Current disposition |
|---|---|
| Private File 2 demo | **Merged on the physical iPad; visible load acceptance open.** The earlier work only staged and tested the level-27 fixture in a disposable Simulator, so the user's repeated physical-device request was not complete. PaperPad was stopped without uninstalling it, and only `Library/Application Support/PaperPad/saves/pm.n64.us.bin` was read. A checksum-valid File 2 was inserted into physical sector 4 at save count 192. Active File 1 remained in sector 3 at count 4 and its complete sector SHA-256 stayed `c5d67e80cc104b13622c63e9271d0451b5f0af6892f375a05714486ba1797ad5`. The exact device read-back matched merged SHA-256 `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398`; PaperPad was relaunched. The private save and temporary copies remain outside the repository. |
| Framing / aspect | **Physical defect confirmed; source repair implemented, device verdict open.** The game legitimately presents a 4:3 image with margins under Original. The old Fill Screen path widened RT64's 3D projection while Paper Mario retained original game-side HUD coordinates. Fill Screen now keeps both RT64 projection paths at Original and center-crops only the completed VI image. This preserves actor/HUD alignment at the cost of cropping edges, especially on wider displays. |
| Text / image filter | **Closed by removal after physical rejection.** Sharp Pixels was visually ineffective and its stronger Crisp 2D replacement made the game look worse without reconstructing source detail. The selector, persistence field, and renderer behavior are removed; Smooth is fixed. Low-resolution text/sprites remain a documented source-asset limitation rather than a fake sharpening promise. |
| Battle target pointer | **Physical cause confirmed; source repair implemented, device verdict open.** The 15:59 screenshot shows the hand far above-left of the selected Spiked Goomba. Paper Mario projects the target's 3D `truePos` into original 4:3 coordinates and draws the hand as 2D HUD, while the prior Fill Screen path independently widened RT64's actor projection. Fill Screen is now final-composite-only so both undergo one transform. No global pointer offset was added. |
| Native controller | **Implementation installed; hardware gate open.** SDL supports hot-plug, left stick/D-pad, A/B/Start, L/R/Z, and right-stick C buttons. The installed build declares controller user interaction and hides gameplay touch controls while a controller is connected, restoring them on disconnect according to the saved Touch Controls toggle. Physical pairing, input mapping, reconnect, menu availability, and sustained gameplay remain untested. |
| Audio | **Still release-blocking.** The user again heard intermittent music crackle after initially thinking it might be gone. The continuous resampler fix remains valid for the measured conversion defect, but it did not eliminate the separate audible synthesis artifact. |

The two supplied screenshots are private physical-device test evidence and are
not copied into the public repository. The replacement build passed arm64
compilation, strict signature verification, ROM/save bundle scans, and clean
vendor-patch replay. It installed in place without replacing the data
container, retained the exact merged save SHA-256 above, and launched as PID
761. Those host-observable checks do not establish visual, controller, battle,
or audible acceptance.

The standard Paper Mario NAUDIO signature (`0x0000127c`) was confirmed from
the exact US 1.0 microcode data. A bounded current-RSPRecomp experiment was
also rejected: standalone `n_aspMain` exited on its first task because it lacks
the RSP boot-provided register/DMEM state. Supplying the ABI table and one
historically suspected register did not repair it. The stable HLE build was
restored and passed the one-Simulator startup/telemetry route. The next audio
implementation candidate must be a complete boot+audio RSP path, not another
buffer, gain, filter, or isolated-register guess.

## 2026-08-11 progress checkpoint

| Issue | Current disposition |
|---|---|
| Audio clipping | **Release blocker; one defect fixed, synthesis crackle remains.** A private 10-second source/output capture proved that the old per-block converter added high-frequency energy (`8.73e-5` of output power above 14 kHz versus `1.55e-6` in its source) and doubled the worst step. A continuous `SDL_AudioStream` removed that measured contamination, and the installed physical build recorded 190 structurally healthy telemetry windows. Hands-on listening then confirmed persistent smaller crackle/clipping. Because peak PCM is well below full scale and queues/conversion are healthy, another gain or buffer-size guess is not justified; the remaining seam is HLE N64 sound synthesis. |
| Crash diagnostics | **iPad Simulator passed; hardware open.** The first-level menu now exposes `Share Diagnostics & Logs…`; private 4 MiB current/previous logs rotate at launch, a 0600 session marker labels a possible unclean prior session, and the share report includes at most 512 KiB from each log. Forced terminate/relaunch preserved and prioritized the previous log. |
| Stick knob | **Shared clamp implemented; physical held-thumb visual open.** The broad pickup region targets the fixed visible origin, and `publishInput` clamps displacement once before deriving both the knob position and N64 vector. Automated drags release between display frames, so hardware must still confirm the held knob never leaves the base. |
| Grid overshoot | **Second tuning implemented; fresh acceptance open.** Earlier iPad+iPhone routes passed discrete `A → B → o` gestures, but hands-on iPad testing still found name entry too eager. Touch-stick output now uses a quadratic precision curve through the inner range and snaps clearly dominant gestures to one cardinal axis while retaining full speed at the rim and intentional diagonals. Build/syntax checks pass; name-entry and normal movement must be re-exercised on Simulator and physical iPad. |
| Compact iPhone controls overlap | **iPhone Simulator fix passed; hardware grip open.** Screenshot review showed that v5 put R/L edge-to-edge and C-up inside L. The `iphone.v6` defaults add visible gaps through the shoulder/C/Z/face stack, preserve the iPad schema, and passed a rebuilt iPhone 17 Pro gameplay-frame review. |
| Auto resolution | **iPad Simulator passed.** Settings showed renderer-confirmed `Auto is currently 7.00x (2240x1680 internal)` and diagnostics reported the same values. |
| Framing | **Borderless base fix passed; presentation-only Fill Screen implemented, physical visual gate open.** Original remains the largest uncropped centered 4:3 image. Fill Screen center-crops the completed image and never changes the game-world projection. Confirm crop preference and battle-HUD alignment before acceptance. |
| Soft assets | **Known limitation documented; misleading filter removed.** Auto and fixed scales improve geometry/sampling but cannot invent source texture, glyph, or sprite detail. Smooth is fixed after Crisp 2D failed its physical value test. No Paper Mario texture pack currently has verified RT64/iOS compatibility, redistribution rights, memory cost, or complete coverage for PaperPad. |
| Settings actions | **Native affordance fix passed visual/source review.** Edit, Reset, Share Diagnostics, and Manage ROM are now consistent 50-point tinted UIKit rows with SF Symbols, backgrounds, rounded corners, accessibility button traits, and full-width hit targets. Done is a filled primary button. Fresh physical-iPad visual/tap acceptance remains open. |
| Later-game save | **Private File 2 inserted safely on the physical iPad; visible load acceptance open.** A checksum-valid level-27 File 2 was merged into a non-active physical sector while preserving the complete active File 1 sector byte-for-byte. Exact CoreDevice read-back and post-update read-back both matched merged save SHA-256 `c7bd66d4e2e971796f636dab6abdedc39d06410a3c142a953168c402bf61e398`. The donor remains ignored/private and must not be committed, packaged, or published. |
| Frame-pacing memory | **New leak reproduced and fixed.** A sustained level-27 run exposed 42,354 retained drawables and 757,314 FramePacing command buffers because RT64 overwrote a retained swap-chain slot without releasing its previous drawable. The maintained replacement/release patch replayed cleanly; the rebuilt run held exactly 3 drawables, 3 lifetimes, and 72 command buffers across thousands of frames, with physical footprint below its 145.3 MiB peak. |
| iOS shutdown crash | **iPhone+iPad Simulator fix passed.** The supplied iPhone report and a fresh iPad reproduction showed `CAMetalLayer` deallocation on RT64's Gfx Thread. RT64 no longer releases SDL/UIKit's unowned layer on iOS; both active-rendering shutdown routes produced no newer report. |
| README visuals | **Implemented.** The stale Settings capture was replaced and the primary visual section reduced to two current images, with the larger audit set linked instead of embedded. |

The current build compiles and launches on one iPad Simulator at a time. None
of the rows above closes physical-iPad audio, touch, or long-session acceptance.
The current arm64 device source compiles and signs with a verified profile that
includes the attached iPad. After the stalled Mac-side CoreDevice worker was
restarted and `devicectl` was run outside the Codex sandbox, a read-only
no-recurse `Documents` listing completed in 0.6 seconds. The signed ROM-free
build was then installed in place, launched, and remained host-observable as a
running process. No backup or container replacement was performed. Hands-on
device acceptance remains open.

## Priority summary

| Priority | Issue | Current observation |
|---|---|---|
| P0 | Goomba Village gate-unlock progression freeze | Goompa and nearby Goombas can stop in place while Mario remains input-locked; Start was initially ignored and normal movement/dialogue did not return |
| P0 | Audible clipping/artifacting | Music clips often enough to be unacceptable; most sound effects are better but not clean enough |
| P1 | Crash diagnostics discoverability and retention | Share Diagnostics exists inside Settings, but was not discoverable during hands-on use and cannot preserve the just-crashed session across relaunch |
| P1 | Analog-stick knob escapes its base | Pulling a thumb far toward a corner can draw the blue knob implausibly far from the fixed stick |
| P1 | Analog navigation repeats too quickly | Name-entry and other grid-style screens skip past intended letters/directions |
| P1 | Auto resolution is opaque | The UI says `Auto` but does not reveal the effective scale or output it selected |
| P1 | Battle target pointer may be offset | The selection hand can appear detached from the actor it targets; exact mode/target capture is required |
| P1 | Native controller parity is incomplete | SDL mappings exist, but physical pairing/reconnect and automatic touch-overlay handoff are not accepted |
| P2 | Framing appears letterboxed | The physical-iPad image did not appear to use as much of the screen as expected |
| P2 | Text and textures remain visibly soft | Higher internal scales do not materially improve some original 2D assets, and the deployed Sharp Pixels path was not visibly distinct |
| P2 | Later-game regression save | A legally shareable, compatible save farther into the game is needed for broader testing |
| P3 | README visual section is too image-heavy | The README is otherwise strong, but Visual verification should show fewer primary images |

## P0: investigate and eliminate audible clipping

### Report

- Music still produces repeated clipping, crackling, or block-like audio
  artifacts on the physical iPad.
- Most sound effects are comparatively acceptable, suggesting the defect may
  be sensitive to sustained music rather than every output sample.
- The game otherwise appeared stable during this session.
- Buffer/cache capacity is a user hypothesis, not an established cause.

### Existing evidence and caution

The earlier PCM overlap correction and absence of a CoreAudio overload line in
one Simulator log did not establish audible hardware quality. Do not close this
issue from queue activity, a clean log, or Simulator playback alone.

### Morning investigation

1. Reproduce on the same physical iPad with the exact song/scene and record a
   short external audio sample plus timestamps.
2. Add bounded counters for source frames, converted frames, queued bytes,
   underruns, excessive queue depth, callback cadence, conversion failures,
   and any dropped/duplicated overlap frames.
3. Compare sustained music against isolated sound effects and compare 48 kHz
   output with the source cadence. Inspect the resampler, channel swap,
   overlap removal, queue-depth correction, and lifecycle resets separately.
4. Test a conservative queue target/buffer change only after the counters show
   underrun or overrun evidence; do not assume “more cache” is the fix.
5. Re-test title music, file selection, File 1A transition, Mario's House, and
   at least one longer music-heavy route on hardware.

### Acceptance

No repeatable crackle, clipping, discontinuity, or pitch/cadence instability in
the exercised hardware routes, with bounded queue behavior and no growing
latency during a longer session. Human listening acceptance is required.

## P1: make diagnostics obvious and useful after a crash

### Current behavior

`PaperPad Menu → Settings → Share Diagnostics…` already creates a system share
sheet. The private current-session stderr log is capped at 4 MiB and the report
shares at most its final 512 KiB. This satisfies the “must not grow forever”
requirement for the active session.

### Remaining problems

- The action was not found during normal use. Consider a first-level
  `Share Diagnostics & Logs…` action in the three-dot menu, or clearer support
  copy in Settings.
- The log is replaced at launch. After a crash, reopening PaperPad can destroy
  the most useful previous-session evidence before the user can share it.
- The current report does not automatically attach an iOS crash report.
- A stale or differently installed build may omit the action; verify the exact
  commit/version on the device before changing the menu.

### Desired design

- Keep bounded `current` and `previous` session logs. Rotate atomically at
  launch and never allow either file to grow without a cap.
- Mark whether the prior session ended cleanly. If not, make the previous log
  the obvious default attachment and label it as a possible crash session.
- Continue excluding ROM/save contents and replacing known private paths.
- Do not claim full anonymization; require review before sharing.
- Investigate whether an available Apple crash report can be offered without
  requesting private device-wide diagnostics or unsupported entitlements.
- Keep log writes and report generation off critical render/audio paths and
  verify that log rotation itself cannot crash or stall the game.

### Acceptance

A normal user can find the action directly from the three-dot menu, reproduce a
crash, relaunch, and share a bounded previous-session report containing enough
context to diagnose the failure without including ROMs, saves, or unreviewed
private data.

## P1: clamp the visible analog-stick knob

### Report

The fixed stick accepts a thumb dragged far toward a screen corner, but the
blue knob can visually float far outside the base. This makes the control look
detached or broken even if the normalized game input is already clamped.

### Direction

- Preserve the broad left-side pickup region and the fixed visible origin.
- Clamp the rendered knob to the base's intended travel radius.
- Confirm the value sent to the N64 stick uses the same normalized/clamped
  vector and returns cleanly to center on lift, cancellation, modal opening,
  rotation, and multi-touch changes.
- Do not turn the fixed visible stick into an unexpectedly floating stick.

### Acceptance

Dragging anywhere on the pickup side can reach full analog magnitude, but the
knob never escapes the base and always recenters without a stuck direction.

## P1: slow analog repeat in text and grid navigation

### Report

During initial file/name entry, small up/down/left/right stick movements repeat
so quickly that the selector skips past the intended character. Similar menu
or grid screens may have the same problem.

### Direction

- Measure whether Paper Mario expects discrete stick edges while PaperPad is
  continuously holding a full analog value.
- Add an initial navigation delay and a slower repeat cadence, or hysteresis
  with neutral re-arm, at the narrowest input seam that fixes UI navigation.
- Avoid globally slowing or quantizing gameplay movement.
- Exercise D-pad, fixed stick, broad pickup region, and simultaneous buttons so
  the change does not create missed input elsewhere.

### Acceptance

A deliberate tilt moves one grid cell, holding produces a controllable delayed
repeat, returning toward neutral re-arms the next move, and ordinary gameplay
movement remains responsive.

## P1: expose Auto's effective rendering scale

### Report

Settings offers `Auto`, `1x`, `2x`, `3x`, and `4x`, but `Auto` does not explain
what it chose. The renderer currently maps Auto to window-integer scaling and
can already report its effective resolution scale in diagnostics.

### Direction

- Show a live explanation such as `Auto (7x, 2240×1680)` or an adjacent
  `Currently …` label based on renderer-confirmed state, not a UI guess.
- Refresh it after rotation, window/screen changes, relaunch, and switching
  between Original and Expand.
- Include the same effective scale/output in Share Diagnostics.
- Keep the distinction between UI selection and renderer-confirmed scale.

### Acceptance

Auto always displays the actual active scale and internal output dimensions,
and those values match the renderer log/report after every relevant change.

## P2: verify framing and the apparent letterbox

### Report

On the physical iPad, Paper Mario appeared more letterboxed and used less of
the screen than expected. `Original` intentionally preserves 4:3, while
`Expand` changes the aspect behavior; that intent does not by itself explain
unexpected margins on a 4:3 iPad display.

### Morning investigation

- Capture labeled physical-iPad screenshots for Original and Expand with the
  exact drawable, safe-area, viewport, and game aspect dimensions.
- Determine whether the margins come from Paper Mario's own scene framing,
  PaperPad's 4:3 viewport, RT64, safe-area handling, or a stale drawable.
- Define expected behavior before changing it: preserve aspect, fill/crop, and
  stretch are different product choices.

### Acceptance

Original uses the largest correctly centered 4:3 viewport allowed by the
screen/safe area, Expand behaves as its label/documentation promises, and no
unexpected extra inset or stale viewport remains.

The revised acceptance rule is explicit: `Original (4:3)` preserves RT64's
standard VI framing; `Fill Screen` center-covers only the completed VI image
and may crop outer content. The setting must produce a visible, reversible
difference on the physical iPad without moving battle pointers relative to
actors, clipping essential HUD, or introducing a stale viewport after
rotation. On wider phones it remains a deliberate final crop, not a
game-unaware expanded scene projection.

## P2: evaluate soft text, textures, and higher-quality assets

### Report

The game generally looks good, but text and many textures remain visibly soft
or low-detail even at higher internal rendering scales. The upscaler can feel
as though it is barely changing those assets.

### Important distinction

Internal resolution improves polygon edges and sampling; it cannot recreate
detail that is absent from original low-resolution text, sprites, or textures.
Treat this as an evidence question, not proof that the scale selector is broken.

### Research/investigation

- Capture the same static scene at Auto and 1x–4x and compare geometry edges,
  text/sprites, texture detail, and performance separately.
- Verify the effective renderer scale rather than relying on the selected tab.
- Inspect RT64's 2D upscale/sampling choices for text and sprite sharpness.
- Research maintained Paper Mario high-resolution texture packs or community
  enhancement work, including RT64 compatibility, completeness, licensing,
  attribution, device memory, load time, and iPad performance.
- Do not bundle or redistribute community/Nintendo-derived assets without a
  documented rights and packaging decision.

### Acceptance

The UI accurately explains what internal scaling can improve; the scale modes
produce renderer-confirmed differences; any sampling change improves text/2D
clarity without shimmer or broken layering; any optional texture-pack path has
clear provenance, licensing, performance, and user-file boundaries.

## P2: obtain a later-game regression save safely

### Goal

Exercise additional chapters, partners, effects, maps, battles, transitions,
music, save slots, and less common renderer/audio paths without replaying the
opening for every regression.

### Direction

- Identify PaperPad's exact flash-save format and whether slots 2–4 are simply
  in the same save image or need separate setup.
- Look for a legally shareable community save with explicit provenance and the
  supported US 1.0 revision, or create a local test save through normal play.
- Validate it in a disposable/private container first. Never overwrite the
  user's live save while evaluating compatibility.
- Keep downloaded/user saves ignored and private unless redistribution rights
  and test-fixture policy are explicitly settled.
- Record named checkpoints so audio, visuals, controls, and transitions can be
  reproduced consistently.

### Acceptance

The private revision-compatible late-game fixture now passes structural checks,
file selection, a Toad Town load, touch movement, unchanged-save hashing, and
bounded runtime telemetry in a disposable Simulator. Acceptance remains open
for named middle-game checkpoints, representative battles/transitions/music,
saving, lifecycle recovery, and a chapter-spanning or 60-minute run without
altering the user's primary save.

## P3: simplify README visual verification

The README is otherwise in good shape. Reduce the Visual verification section
to the strongest two or three representative images. Move secondary comparison
captures into a collapsed details block or link to `docs/release-audit/` so the
project page remains quick to scan without discarding evidence.

## Goal-based execution plan

### Goal

Resolve and validate every issue in this document, ending with ROM-free iPhone
and iPad builds whose audio, controls, rendering choices, framing, diagnostics,
and documented acceptance boundaries are supported by reproducible evidence.

### Working rules

- Preserve the physical iPad's ROM, saves, settings, and control layouts.
- Use the same bundle identifier and an in-place update; never remove or
  replace the live app container as a shortcut.
- Do not copy whole `Documents` or `Library` trees unless the user explicitly
  requests it. Limit any preservation or diagnostic read-back to the exact,
  user-approved file needed for the current check.
- Run only one Simulator or physical-device test route at a time.
- Diagnose before tuning: do not turn “cache,” “upscaler,” or “letterbox”
  hypotheses into fixes until runtime evidence identifies the responsible path.
- Do not close hardware audio, visual, or touch issues from a successful build,
  PID, log line, or Simulator result alone.

### Phase 0: freeze a reproducible baseline

1. Record the exact source commit, device/Simulator artifact hashes, bundle
   version, iPad model/runtime, current settings, and save/ROM hashes.
2. Confirm the same-bundle in-place update path and identify any exact,
   user-approved preservation read-back without copying unrelated folders.
3. Capture short, named reproduction routes for audio clipping, stick escape,
   name-entry overshoot, Auto resolution, and apparent letterboxing.
4. Preserve before/after screenshots and external audio recordings without
   including private game data in the repository.

**Gate:** every later change can be compared with the same build, route,
settings, and private-data baseline.

### Phase 1: clear the P0 audio blocker

1. Reproduce clipping on physical iPad at the title, file selection, File 1A,
   Mario's House, and a longer sustained-music route.
2. Add bounded instrumentation for source/converted frames, queue depth,
   underruns/overruns, cadence, overlap removal, and conversion failures.
3. Isolate resampling, channel swapping, frame overlap, queue correction,
   lifecycle reset, and HLE production rather than changing all at once.
4. Apply the smallest evidence-supported fix and compare recordings/logs from
   identical routes.
5. Run a longer session to rule out growing latency or delayed degradation.

**Gate:** human listening acceptance on hardware, clean bounded telemetry, and
no regression in sound effects, cadence, stability, or latency.

### Phase 2: make support diagnostics crash-ready

1. Verify whether the exact installed build shows the existing Settings action.
2. Add or duplicate `Share Diagnostics & Logs…` at the first-level menu.
3. Rotate bounded `current` and `previous` logs atomically and record whether
   the prior session exited cleanly.
4. Default to the previous log after a suspected crash and clearly label it.
5. Investigate safe access to an app-specific Apple crash report; do not request
   device-wide private diagnostics or unsupported entitlements.
6. Stress log volume, launch rotation, crash/relaunch, report generation,
   privacy replacement, backup exclusion, and share dismissal.

**Gate:** a normal user can reproduce a crash, relaunch, find the action, and
share a bounded, reviewable prior-session report without ROM/save contents.

### Phase 3: repair touch controls without broad input changes

1. Clamp the visible stick knob and its normalized value to the fixed base's
   travel radius while preserving the broad pickup region.
2. Verify recentering on lift, cancellation, modal presentation, rotation, and
   multi-touch changes.
3. Measure name-entry/grid input and implement neutral re-arm plus controlled
   initial delay/repeat at the narrowest appropriate input seam.
4. Keep gameplay analog movement continuous and responsive.
5. Regress D-pad, stick, simultaneous face buttons, modal clearing, layout edit,
   saved layouts, iPhone geometry, and iPad geometry.

**Gate:** no escaped/stuck knob, controllable one-cell grid navigation, and no
movement or multi-touch regression in gameplay.

### Phase 4: make resolution and aspect behavior explain themselves

1. Bridge renderer-confirmed active scale and internal output dimensions back
   to Settings and diagnostics.
2. Display `Auto` with its live result and refresh after rotation, relaunch,
   aspect change, and screen/window changes.
3. Reconfirm Auto plus 1x–4x selection, effective renderer state, framebuffer
   rebuild, and persistence on both Simulator device classes.
4. Capture physical-iPad Original and Expand geometry with safe-area, drawable,
   viewport, and game-aspect dimensions.
5. Fix only unintended extra inset or stale viewport; preserve the documented
   aspect behavior unless the product definition is deliberately changed.

**Gate:** displayed values match renderer evidence, every mode is distinct and
persistent, and Original/Expand framing matches an explicitly documented rule.

### Phase 5: separate render resolution from asset quality

1. Capture one identical scene at Auto and 1x–4x, separating polygon edges,
   text/sprites, texture detail, layering, and performance.
2. Evaluate RT64 2D sampling/upscale options for sharper text without shimmer.
3. Research maintained Paper Mario high-resolution texture or enhancement work.
4. Record compatibility, completeness, provenance, licensing, attribution,
   memory, load-time, and iPad-performance findings.
5. Keep community/Nintendo-derived assets user-supplied unless a separate rights
   and packaging decision supports redistribution.

**Gate:** PaperPad accurately explains internal scaling limits; any sampling or
optional enhancement path improves the intended assets without visual,
performance, licensing, or packaging regressions.

Both `Sharp Pixels` and its stronger `Crisp 2D` replacement failed the physical
value test. Crisp 2D made the image visibly worse, so the experiment was
removed instead of being retained as a misleading advanced option. Future
clarity work must demonstrate a genuine improvement on original text/HUD and
must not be described as reconstructing detail that is absent from the source.

## P1: verify battle target-pointer alignment

### Report

- During battle target selection, the downward hand appeared to indicate a
  location that did not match the selected actor.
- The supplied 15:59 physical screenshot captures the pointer far above-left
  of the selected Spiked Goomba and establishes the defect directly.
- Paper Mario derives the pointer from the selected target's 3D `truePos`,
  projects it with the battle camera, and draws the hand as a 2D HUD element.

### Acceptance

Capture the same target in Original and the new presentation-only Fill Screen
with the hand visible. In both modes it must remain centered above the selected
actor/part throughout target changes and camera motion. The source repair keeps
regular and extended GBI projection at Original and applies Fill only to the
completed VI frame; no global magic HUD offset is permitted.

## P1: complete native-controller handoff

### Direction

- Keep the existing SDL controller mapping and hot-plug path.
- Advertise Apple's ExtendedGamepad plus controller-user interaction.
- Hide and clear gameplay touch targets when a physical controller connects;
  keep the PaperPad menu reachable, and restore touch targets on disconnect
  only when the saved Touch Controls toggle is enabled.
- Do not claim rumble, motion, or a specific controller model without direct
  hardware evidence.

### Acceptance

On the physical iPad, pair an iOS-supported controller and verify title Start,
file/menu navigation, analog movement, D-pad, A/B/Z/L/R, all C directions,
connect/disconnect/reconnect, no stuck input, menu access, and automatic touch
hide/restore during sustained gameplay. Record the controller model and OS.

### Phase 6: add later-game regression coverage safely

1. Document the flash-save format and slot layout.
2. Back up the user's live save and use a disposable/private container.
3. Find a provenance-clear compatible US 1.0 save or create one through play.
4. Validate slots and define named early-, middle-, and later-game checkpoints.
5. Exercise battles, partners, effects, transitions, maps, music, saving/loading,
   resolution changes, and lifecycle recovery at those checkpoints.

**Gate:** a private, backed-up regression save reaches documented checkpoints
without modifying the user's primary save or entering a public artifact.

### Phase 7: simplify and correct public documentation

1. Reduce README Visual verification to the strongest two or three images.
2. Move secondary evidence behind a details block or `docs/release-audit/` link.
3. Document Auto's effective value, Original/Expand behavior, diagnostics and
   prior-crash retention, upscaling/texture limits, and save-test provenance.
4. Update status, testing, known issues, handoff, and release checklist from the
   final evidence only; do not roll old target evidence forward.

**Gate:** the README is concise, support instructions are findable, claims match
the tested artifacts, and every remaining limitation is explicit.

### Phase 8: sequential final acceptance and release

1. Produce clean ROM-free Release builds and run repository/package audits.
2. Test iPad Simulator, shut it down, then test iPhone Simulator and shut it
   down; never boot both simultaneously.
3. Install in place on physical iPad without removing or replacing its data
   container, then exercise audio, visuals, controls, settings, diagnostics,
   lifecycle, thermals, saves, and a long session. Repeat on physical iPhone if
   available before claiming it.
4. Review current/previous logs, crashes, warnings, memory, and artifact contents.
5. Update validation evidence, run source/patch/safety checks, review the diff,
   open a focused PR, merge only after gates pass, confirm local/remote `main`
   parity, and install the exact merged device build.

**Gate:** all P0/P1 items pass, P2 items are either fixed or explicitly resolved
with evidence, documentation matches reality, the final artifact is ROM-free,
and hands-on physical-device acceptance is recorded rather than inferred.

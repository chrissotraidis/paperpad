# PaperPad v0.1.0-preview.2

Preview 2 is a targeted controller sleep, disconnect, and reconnect reliability update.

## Download

- `PaperPad-v0.1.0-preview.2-unsigned.ipa`
- `PaperPad-v0.1.0-preview.2-unsigned.ipa.sha256`

SHA-256: `ea908c33fce6ba883acadff3ccc3025a1a7ef0284947c09cf98f3602af84d029`

The IPA is ROM-free and unsigned. Sign it with your own Apple credentials before installation, then import your own legally obtained, unmodified Paper Mario (US) 1.0 ROM through PaperPad's file picker. See [IPA installation](INSTALL_IPA.md). Updating an existing signed copy should use the same bundle ID and an in-place install; uninstalling can remove its private ROM, saves, and settings.

## Controller reliability

- PaperPad's existing SDL2 controller backend now reconciles current devices, attached handles, instance IDs, and player slots instead of relying on removal events alone.
- A valid controller keeps its slot; a stale handle closes and releases held buttons/axes; a sole returning controller takes player 1; an additional controller takes the next free slot without displacing player 1.
- Reconciliation runs after controller events, during active use, and on foreground resume without restarting the controller subsystem.
- Runtime diagnostics record the reason, instance ID, player slot, device index, and controller name for assignments and releases.

## Verification boundary

- Deterministic tests passed single-controller reconnect, two-controller slot preservation, held-input release, a missed removal event, and foreground reconciliation.
- Complete macOS and iOS builds, repository audits, package audits, and two deterministic IPA package runs passed.
- The exact signed release candidate installed in place and booted into active gameplay on the attached iPad. Exact pre/post comparisons confirmed its existing private ROM files, save and backup, ROM selection, and controller/touch preferences were unchanged.
- Physical Bluetooth reconnect, wired reconnect, natural controller sleep/wake, full mapping, and two-physical-controller behavior were not exercised and remain acceptance work.

This is an unsigned public preview, not an App Store or TestFlight release. No game data or saves are included. The release tag is the corresponding source snapshot. PaperPad is unofficial and is not affiliated with or endorsed by Nintendo or any upstream project.

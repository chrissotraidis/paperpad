# Install the unsigned PaperPad IPA

PaperPad `v0.1.0-preview.1` is distributed as a **ROM-free, unsigned** IPA. It is not an App Store or TestFlight build. You must sign it with your own Apple credentials before installing it on an iPhone or iPad.

## Before installing

- Use an arm64 iPhone or iPad running iOS/iPadOS 15 or newer.
- Download `PaperPad-v0.1.0-preview.1-unsigned.ipa` and its `.sha256` file from the matching GitHub release.
- Verify the checksum with `shasum -a 256 -c PaperPad-v0.1.0-preview.1-unsigned.ipa.sha256` on macOS.
- Have your own legally obtained, unmodified Paper Mario (US) 1.0 ROM ready in Files. The IPA does not contain game data.

## Sign and install

Use a sideloading tool that signs an unsigned IPA with your own Apple ID or development certificate, such as AltStore/AltServer, Sideloadly, or an equivalent Xcode-based workflow. Follow that tool's current instructions and keep your credentials private.

Free Apple ID signatures normally expire and must be refreshed periodically. Paid Apple Developer signing has different limits. PaperPad cannot control those Apple signing rules.

After installation:

1. Open PaperPad.
2. Choose **Choose ROM**.
3. Select your supported ROM from Files.
4. Wait for local validation and private import to finish.
5. Press the on-screen Start button or connect a supported controller.

PaperPad stores the imported ROM, saves, settings, and diagnostics inside its private app container. When updating, use the same bundle identifier/signing setup and install in place; uninstalling can remove that private data.

## Troubleshooting

- **Integrity or developer error:** re-sign the unsigned IPA with your own active certificate/profile.
- **App opens but asks for a ROM:** expected; import your own supported ROM through the picker.
- **ROM rejected:** verify that it is the unmodified US 1.0 revision documented in the README.
- **Gameplay problem:** reproduce it, open **PaperPad Menu → Share Diagnostics & Logs…**, review/redact the report, and attach it to a bug report without any ROM or save data.

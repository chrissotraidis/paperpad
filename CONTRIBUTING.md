# Contributing to PaperPad

Issues and pull requests are welcome for reproducible Apple-platform defects, build/documentation fixes, and clearly scoped improvements.

Before opening an issue, search existing reports and include:

- the PaperPad commit or release identifier;
- the platform, device, and OS version;
- the exact build/install command;
- steps to reproduce and the expected and actual result; and
- relevant non-sensitive logs or screenshots.

On iPhone or iPad, use **PaperPad Menu > Share Diagnostics & Logs…** after reproducing the problem. The report contains bounded tails from the current session and, when available, the previous session; a previous unclean session is labeled as a possibility, not definitive proof of an app crash. Review and redact it before attaching it: known container/home/temporary paths are replaced, but arbitrary runtime text can still contain private material.

Never attach, request, link to, or commit ROMs, extracted game assets, generated playable source or archives, saves, raw PCM captures, certificates, provisioning profiles, private keys, credentials, or private device data.

For a change:

1. Preserve the pins in `dependencies.lock.json` unless the change explicitly updates and validates a dependency.
2. Keep the maintained patch order in `scripts/apply-patches.sh` reproducible and idempotent.
3. Run the applicable macOS and/or iOS Simulator build and exercise the changed flow.
4. Run `scripts/check-repo-safety.sh` and `git diff --check`.
5. Update user-facing documentation and the dated acceptance boundary when behavior changes.

Read [RIGHTS_AND_LICENSES.md](RIGHTS_AND_LICENSES.md) before proposing redistribution, packaging, or store-submission work.

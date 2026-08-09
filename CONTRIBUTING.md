# Contributing to PaperPad

Issues and pull requests are welcome for reproducible Apple-platform defects, build/documentation fixes, and clearly scoped improvements.

Before opening an issue, search existing reports and include:

- the PaperPad commit or release identifier;
- the platform, device, and OS version;
- the exact build/install command;
- steps to reproduce and the expected and actual result; and
- relevant non-sensitive logs or screenshots.

Never attach, request, link to, or commit ROMs, extracted game assets, generated playable source or archives, saves, certificates, provisioning profiles, private keys, credentials, or private device data.

For a change:

1. Preserve the pins in `dependencies.lock.json` unless the change explicitly updates and validates a dependency.
2. Keep the maintained patch order in `scripts/apply-patches.sh` reproducible and idempotent.
3. Run the applicable macOS and/or iOS Simulator build and exercise the changed flow.
4. Run `scripts/check-repo-safety.sh` and `git diff --check`.
5. Update user-facing documentation and the dated acceptance boundary when behavior changes.

Read [RIGHTS_AND_LICENSES.md](RIGHTS_AND_LICENSES.md) before proposing redistribution, packaging, or store-submission work.

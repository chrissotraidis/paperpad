# Historical source-preparation records

No file here is applied by normal builds. The 25 formerly active patches are mapped to ordinary maintained source commits in [patch-map.json](../docs/source-maintenance/patch-map.json). The five `mstan-*` records were already historical. Keep these files as provenance and for a disposable rollback replay only.

The former clean replay was incomplete: `metal-worker-lifetime.patch` combines an already-present present-queue hunk with remaining worker changes. The maintained source imports the exact verified prepared result instead. New fixes belong in `vendor/paper-mario-recut` source and its upstream-connected fork, not in another patch file.

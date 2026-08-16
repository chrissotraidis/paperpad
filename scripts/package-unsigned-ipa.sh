#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP="${PAPERPAD_IOS_DEVICE_APP:-$ROOT/build-ios-device/Release/PaperPad.app}"
OUTPUT="${PAPERPAD_UNSIGNED_IPA_OUTPUT:-$ROOT/artifacts/PaperPad-v0.1.0-preview.2-unsigned.ipa}"

[[ "$APP" = /* ]] || APP="$ROOT/$APP"
[[ "$OUTPUT" = /* ]] || OUTPUT="$ROOT/$OUTPUT"
[[ -d "$APP" ]] || { echo "PaperPad device app not found: $APP" >&2; exit 1; }
[[ -x "$APP/PaperPad" ]] || { echo "PaperPad executable not found in: $APP" >&2; exit 1; }

package_root="$(mktemp -d /tmp/paperpad-package.XXXXXX)"
trap 'rm -rf "$package_root"' EXIT
staged_app="$package_root/Payload/PaperPad.app"
mkdir -p "$staged_app/Licenses" "$(dirname -- "$OUTPUT")"
ditto "$APP" "$staged_app"

# A public IPA cannot carry this Mac's development identity or provisioning
# profile. Users sign the archive themselves with their own Apple credentials.
codesign --remove-signature "$staged_app" 2>/dev/null || true
rm -rf "$staged_app/_CodeSignature"
rm -f "$staged_app/embedded.mobileprovision"

ditto "$ROOT/docs/INSTALL_IPA.md" "$staged_app/INSTALL_IPA.md"
ditto "$ROOT/RIGHTS_AND_LICENSES.md" "$staged_app/RIGHTS_AND_LICENSES.md"

copy_license() {
    local source="$1"
    local destination="$2"
    [[ -f "$source" ]] || { echo "Required license file missing: $source" >&2; exit 1; }
    mkdir -p "$(dirname -- "$staged_app/Licenses/$destination")"
    ditto "$source" "$staged_app/Licenses/$destination"
}

copy_license "$ROOT/ref/paper-mario-recut/LICENSE" "Paper-Mario-ReCut/LICENSE"
copy_license "$ROOT/ref/paper-mario-recut/COMPLIANCE.md" "Paper-Mario-ReCut/COMPLIANCE.md"
copy_license "$ROOT/ref/paper-mario-recut/THIRD_PARTY_NOTICES.md" "Paper-Mario-ReCut/THIRD_PARTY_NOTICES.md"
copy_license "$ROOT/ref/paper-mario-recut/lib/N64ModernRuntime/COPYING" "N64ModernRuntime/COPYING"
copy_license "$ROOT/ref/paper-mario-recut/lib/N64ModernRuntime/N64Recomp/LICENSE" "N64Recomp/LICENSE"
copy_license "$ROOT/ref/paper-mario-recut/lib/rt64/LICENSE" "RT64/LICENSE"
copy_license "$ROOT/ref/SDL2/LICENSE.txt" "SDL2/LICENSE.txt"
copy_license "$ROOT/ref/zstd/LICENSE" "zstd/LICENSE"
copy_license "$ROOT/ref/mupen64plus-rsp-hle/LICENSES" "mupen64plus-rsp-hle/LICENSES"

# Preserve the notices for statically linked transitive components without
# flattening filenames that may collide.
for relative in \
    N64Recomp/lib/fmt/LICENSE \
    N64Recomp/lib/rabbitizer/LICENSE \
    thirdparty/miniz/LICENSE \
    thirdparty/o1heap/LICENSE \
    thirdparty/xxHash/LICENSE; do
    copy_license "$ROOT/ref/paper-mario-recut/lib/N64ModernRuntime/$relative" "N64ModernRuntime/$relative"
done
for relative in \
    hlslpp/LICENSE \
    im3d/LICENSE \
    imgui/LICENSE.txt \
    metal-cpp/LICENSE.txt \
    nativefiledialog-extended/LICENSE \
    re-spirv/LICENSE \
    spirv-cross/LICENSE \
    stb/LICENSE \
    xxHash/LICENSE \
    zstd/LICENSE; do
    copy_license "$ROOT/ref/paper-mario-recut/lib/rt64/src/contrib/$relative" "RT64/contrib/$relative"
done

find "$package_root/Payload" -exec touch -h -t 202001010000 {} +
archive_tmp="$package_root/PaperPad.ipa"
(
    cd "$package_root"
    export COPYFILE_DISABLE=1
    find Payload -print | LC_ALL=C sort | zip -X -q "$archive_tmp" -@
)
mv -f "$archive_tmp" "$OUTPUT"

"$ROOT/scripts/audit-ios-package.sh" "$OUTPUT"
(
    cd "$(dirname -- "$OUTPUT")"
    shasum -a 256 "$(basename -- "$OUTPUT")" >"$(basename -- "$OUTPUT").sha256"
)

echo "Unsigned IPA: $OUTPUT"
cat "$OUTPUT.sha256"
echo "This IPA must be signed with the user's own Apple credentials before installation."

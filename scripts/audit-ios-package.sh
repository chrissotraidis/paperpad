#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
IPA="${1:?usage: scripts/audit-ios-package.sh <PaperPad.ipa>}"
[[ "$IPA" = /* ]] || IPA="$ROOT/$IPA"

fail() {
    echo "PaperPad IPA audit failed: $*" >&2
    exit 1
}

[[ -f "$IPA" ]] || fail "IPA not found: $IPA"
unzip -tq "$IPA" >/dev/null || fail "ZIP integrity check failed"

entries="$(unzip -Z1 "$IPA")"
for required in \
    Payload/PaperPad.app/PaperPad \
    Payload/PaperPad.app/Info.plist \
    Payload/PaperPad.app/PrivacyInfo.xcprivacy \
    Payload/PaperPad.app/ThirdPartyNotices.txt \
    Payload/PaperPad.app/INSTALL_IPA.md \
    Payload/PaperPad.app/RIGHTS_AND_LICENSES.md \
    Payload/PaperPad.app/Licenses/Paper-Mario-ReCut/LICENSE \
    Payload/PaperPad.app/Licenses/Paper-Mario-ReCut/COMPLIANCE.md \
    Payload/PaperPad.app/Licenses/N64ModernRuntime/COPYING \
    Payload/PaperPad.app/Licenses/N64Recomp/LICENSE \
    Payload/PaperPad.app/Licenses/RT64/LICENSE \
    Payload/PaperPad.app/Licenses/SDL2/LICENSE.txt \
    Payload/PaperPad.app/Licenses/zstd/LICENSE \
    Payload/PaperPad.app/Licenses/mupen64plus-rsp-hle/LICENSES; do
    grep -Fxq "$required" <<<"$entries" || fail "required file missing: $required"
done

if grep -Eq '(^|/)\.\.(/|$)|^/|(^|/)__MACOSX(/|$)' <<<"$entries"; then
    fail "archive contains an unsafe path"
fi
if grep -Eiq '(^|/)(generated|ref|user|saves?|logs?)(/|$)|\.(z64|n64|v64|rom|elf|fla|sav|srm|log|mobileprovision|provisionprofile|p12|p8|pem|key|cer)$|(^|/)_CodeSignature(/|$)|(^|/)pm\.n64\.us\.bin$' <<<"$entries"; then
    fail "archive contains game data, local output, a save/log, or signing material"
fi

extract_root="$(mktemp -d /tmp/paperpad-ipa-audit.XXXXXX)"
trap 'rm -rf "$extract_root"' EXIT
unzip -q "$IPA" -d "$extract_root"
app="$extract_root/Payload/PaperPad.app"
executable="$app/PaperPad"

[[ "$(find "$extract_root/Payload" -mindepth 1 -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')" = 1 ]] ||
    fail "IPA must contain exactly one app"
[[ "$(lipo -archs "$executable")" = arm64 ]] || fail "app is not arm64-only"
xcrun vtool -show-build "$executable" | grep -Eq 'platform +IOS$' || fail "app is not an iPhoneOS product"
xcrun vtool -show-build "$executable" | grep -Eq 'minos +15\.0$' || fail "app minimum OS is not iOS 15.0"

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$app/Info.plist"
}
[[ "$(plist_value CFBundleIdentifier)" = com.chrissotraidis.paperpad ]] || fail "unexpected bundle identifier"
[[ "$(plist_value CFBundleShortVersionString)" = 0.1.0 ]] || fail "unexpected app version"
[[ "$(plist_value CFBundleVersion)" = 2 ]] || fail "unexpected app build number"
[[ "$(plist_value MinimumOSVersion)" = 15.0 ]] || fail "unexpected Info.plist minimum OS"
[[ "$(plist_value ITSAppUsesNonExemptEncryption)" = false ]] || fail "encryption declaration is not false"

plutil -lint "$app/PrivacyInfo.xcprivacy" >/dev/null || fail "privacy manifest is invalid"
plutil -extract NSPrivacyTracking raw "$app/PrivacyInfo.xcprivacy" | grep -Fxq false ||
    fail "privacy manifest unexpectedly declares tracking"

[[ ! -d "$app/_CodeSignature" && ! -f "$app/embedded.mobileprovision" ]] ||
    fail "unsigned package contains signing material"
codesign --verify --strict "$app" >/dev/null 2>&1 && fail "app is still signed"
otool -l "$executable" | grep -q 'cmd LC_CODE_SIGNATURE' && fail "executable still contains a code signature"
otool -l "$executable" | grep -q 'cmd LC_RPATH' && fail "executable contains a runtime search path"

unexpected_runtime="$(otool -L "$executable" | awk 'NR > 1 { print $1 }' | rg -v '^(/System/Library/|/usr/lib/)' || true)"
[[ -z "$unexpected_runtime" ]] || fail "app has an unbundled runtime dependency: $unexpected_runtime"

cmp -s "$ROOT/apple/app/ThirdPartyNotices.txt" "$app/ThirdPartyNotices.txt" ||
    fail "bundled notices differ from the repository"

if LC_ALL=C strings -a "$executable" | grep -E '/Users/|/Volumes/|/private/var/folders/|github_pat_|gh[pousr]_|AKIA[0-9A-Z]{16}' >/dev/null; then
    fail "executable contains a personal build path or likely credential"
fi

echo "PaperPad IPA audit passed: $IPA"

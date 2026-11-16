#!/bin/zsh
# Build Sweep.app into build/ with Sparkle.framework embedded, and sign it.
# Signing: with the "Sweep Self-Signed" certificate when it is in the keychain
# (made once by the maintainer). The certificate stays the same, so macOS
# keeps the Accessibility grant after a new build or an update. Without it, the build is
# signed ad-hoc: that changes on every build, so macOS may drop the Accessibility grant.
# Env: SWEEP_SIGN_IDENTITY (certificate name), SWEEP_KEYCHAIN (keychain file to use),
# SWEEP_PUBLIC_KEY_FILE (test-only: another public update key file).
# The second-to-last output line is SIGNED_WITH=<identity|adhoc>; the last is the app path.
set -euo pipefail
cd "${0:A:h}/.."
source scripts/archs.sh
# Universal (arm64 + x86_64). A multi-arch build puts its products in another folder: ask SwiftPM for it.
ARCH_ARGS=(); for a in $SWEEP_ARCHS; do ARCH_ARGS+=(--arch $a); done
swift build -c release "${ARCH_ARGS[@]}" >/dev/null
VERSION_STR=$(tr -d '[:space:]' < VERSION)
BUILD_NUM=$(git rev-list --count HEAD)
APP=build/Sweep.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN=$(swift build -c release "${ARCH_ARGS[@]}" --show-bin-path)
cp "$BIN/Sweep" "$APP/Contents/MacOS/Sweep"
mkdir -p "$APP/Contents/Frameworks"
ditto "$BIN/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# Brand: build the icon set from the 1024 px master, then copy the Welcome / About art.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/Brand/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/Brand/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Brand/*.jpg "$APP/Contents/Resources/"
# Licenses: Sweep's GPL-3.0 text and Sparkle's MIT notice (names match LicenseNotice in SweepCore).
SPARKLE_LICENSE=.build/checkouts/Sparkle/LICENSE
[[ -s $SPARKLE_LICENSE ]] || SPARKLE_LICENSE=.build/artifacts/sparkle/Sparkle/LICENSE
[[ -s LICENSE && -s $SPARKLE_LICENSE ]] || { echo "error: LICENSE or Sparkle's LICENSE is missing" >&2; exit 1; }
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp "$SPARKLE_LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.nikohtr.sweep</string>
  <key>CFBundleName</key><string>Sweep</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>Sweep</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION_STR</string>
  <key>CFBundleVersion</key><string>$BUILD_NUM</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>SUFeedURL</key><string>https://github.com/Nikohtr/sweep/releases/latest/download/appcast.xml</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUScheduledCheckInterval</key><integer>86400</integer>
  <key>SUAutomaticallyUpdate</key><false/>
</dict></plist>
PLIST
# The public half of the update-signing key. Without it, the app runs with updates off.
KEY_FILE=${SWEEP_PUBLIC_KEY_FILE:-Resources/Release/SUPublicEDKey.txt}
if [[ -s $KEY_FILE ]]; then
  plutil -insert SUPublicEDKey -string "$(tr -d '[:space:]' < $KEY_FILE)" "$APP/Contents/Info.plist"
else
  echo "warning: no $KEY_FILE: updates are off in this build" >&2
fi

check_universal "$APP" || exit 1

IDENTITY=${SWEEP_SIGN_IDENTITY:-Sweep Self-Signed}
KC=(); [[ -n ${SWEEP_KEYCHAIN:-} ]] && KC=(--keychain "$SWEEP_KEYCHAIN")
if security find-identity -p codesigning ${SWEEP_KEYCHAIN:+"$SWEEP_KEYCHAIN"} | grep -qF "\"$IDENTITY\""; then
  SIGN=$IDENTITY
else
  SIGN=-
  echo "warning: no \"$IDENTITY\" certificate: signing ad-hoc, so Accessibility may reset after each build" >&2
fi
# Inside out: nested helpers first, then the framework, then the app. No --deep.
FW="$APP/Contents/Frameworks/Sparkle.framework"
for code in "$FW/Versions/B/XPCServices/Installer.xpc" "$FW/Versions/B/XPCServices/Downloader.xpc" \
            "$FW/Versions/B/Autoupdate" "$FW/Versions/B/Updater.app" "$FW" "$APP"; do
  extra=(); [[ $code == *Downloader.xpc ]] && extra=(--preserve-metadata=entitlements)
  codesign --force --sign "$SIGN" "${KC[@]}" "${extra[@]}" "$code" >/dev/null 2>&1 \
    || { echo "error: codesign failed for $code" >&2; exit 1; }
done
[[ $SIGN == - ]] && echo "SIGNED_WITH=adhoc" || echo "SIGNED_WITH=$SIGN"
echo "$APP"

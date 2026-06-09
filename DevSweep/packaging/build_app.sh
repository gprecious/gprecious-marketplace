#!/usr/bin/env bash
# DevSweep — Developer ID distribution build pipeline.
#
# Assembles a .app bundle from the SwiftPM release binary, signs it, and
# (optionally) notarizes + staples it for direct distribution. DevSweep is NOT
# sandboxed and is NOT shipped via the Mac App Store — see DevSweep.entitlements.
#
# Usage:
#   ./packaging/build_app.sh --adhoc            # local: build + ad-hoc sign (launch test)
#   IDENTITY="Developer ID Application: Taejin Yoo (TEAMID)" ./packaging/build_app.sh
#   IDENTITY="..." NOTARY_PROFILE=devsweep ./packaging/build_app.sh --dmg   # full release
#
# Env:
#   IDENTITY        codesign identity (required unless --adhoc). e.g.
#                   "Developer ID Application: Taejin Yoo (XXXXXXXXXX)"
#   NOTARY_PROFILE  notarytool keychain profile (see notarize note below). If set
#                   (and not --adhoc), submits for notarization and staples.
#   VERSION         override CFBundleShortVersionString (default: Info.plist value)
#   BUILD           override CFBundleVersion           (default: Info.plist value)
#   UNIVERSAL=1     build a universal (arm64 + x86_64) binary
#
# Flags:
#   --adhoc      ad-hoc sign ("-") for local testing; skips notarization
#   --dmg        also build a distributable DevSweep-<version>.dmg
#   --no-build   reuse the existing release build (skip `swift build`)
#
# One-time notarization credential setup the user runs themselves (NOT done here):
#   xcrun notarytool store-credentials devsweep \
#     --apple-id "<your apple id email>" --team-id "<TEAMID>" \
#     --password "<app-specific password from appleid.apple.com>"
set -euo pipefail

PKG="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$PKG/.." && pwd)"
OUT="$PROJ/build"
APP="$OUT/DevSweep.app"

ADHOC=0; MAKE_DMG=0; DO_BUILD=1
for arg in "$@"; do
  case "$arg" in
    --adhoc) ADHOC=1 ;;
    --dmg) MAKE_DMG=1 ;;
    --no-build) DO_BUILD=0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi

echo "==> DevSweep build pipeline (adhoc=$ADHOC dmg=$MAKE_DMG)"

# 1. Build release binary
if [ "$DO_BUILD" = "1" ]; then
  echo "==> swift build -c release ${ARCH_FLAGS[*]:-}"
  ( cd "$PROJ" && swift build -c release "${ARCH_FLAGS[@]}" )
fi
BIN="$(cd "$PROJ" && swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"
[ -x "$BIN/DevSweepApp" ] || { echo "release binary not found at $BIN/DevSweepApp" >&2; exit 1; }

# 2. Assemble .app bundle
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/DevSweepApp" "$APP/Contents/MacOS/DevSweep"
cp "$PKG/Info.plist" "$APP/Contents/Info.plist"

PB=/usr/libexec/PlistBuddy
[ -n "${VERSION:-}" ] && "$PB" -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
[ -n "${BUILD:-}" ] && "$PB" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"

# SwiftPM resource bundle (carries DevSweep.storekit; harmless on Developer ID).
if [ -d "$BIN/DevSweep_DevSweepApp.bundle" ]; then
  cp -R "$BIN/DevSweep_DevSweepApp.bundle" "$APP/Contents/Resources/"
fi

# 3. Icon (generate placeholder master once, cache it, build .icns)
MASTER="$PKG/icon-master.png"
if [ ! -f "$MASTER" ]; then
  echo "==> generating placeholder icon"
  ( cd "$PROJ" && swift "$PKG/IconGen.swift" "$MASTER" )
fi
ICONSET="$OUT/DevSweep.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png 16;      gen icon_16x16@2x.png 32
gen icon_32x32.png 32;      gen icon_32x32@2x.png 64
gen icon_128x128.png 128;   gen icon_128x128@2x.png 256
gen icon_256x256.png 256;   gen icon_256x256@2x.png 512
gen icon_512x512.png 512;   gen icon_512x512@2x.png 1024
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/DevSweep.icns"
rm -rf "$ICONSET"

# 4. Sign
# Only pass --entitlements when the file actually declares one (AMFI rejects a
# commented/empty entitlements plist). With no entitlements, Hardened Runtime
# defaults are correct for DevSweep — see DevSweep.entitlements.
ENT_ARG=()
if grep -q "<key>" "$PKG/DevSweep.entitlements" 2>/dev/null; then
  ENT_ARG=(--entitlements "$PKG/DevSweep.entitlements")
  echo "==> using entitlements: $PKG/DevSweep.entitlements"
fi
if [ "$ADHOC" = "1" ]; then
  echo "==> ad-hoc signing (local test only)"
  codesign --force --sign - --timestamp=none "${ENT_ARG[@]}" "$APP"
else
  : "${IDENTITY:?set IDENTITY to a 'Developer ID Application: …' codesign identity, or pass --adhoc}"
  echo "==> signing with: $IDENTITY (Hardened Runtime)"
  codesign --force --options runtime --timestamp \
    "${ENT_ARG[@]}" \
    --sign "$IDENTITY" "$APP"
fi
echo "==> codesign verify"
codesign --verify --strict --verbose=2 "$APP"

# 5. Notarize + staple (real identity + NOTARY_PROFILE only)
if [ "$ADHOC" != "1" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
  ZIP="$OUT/DevSweep-notarize.zip"
  echo "==> notarizing via profile '$NOTARY_PROFILE' (this can take a few minutes)"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  echo "==> Gatekeeper assessment"
  spctl -a -vvv -t exec "$APP" || true
fi

# 6. DMG
if [ "$MAKE_DMG" = "1" ]; then
  VER="$("$PB" -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
  DMG="$OUT/DevSweep-$VER.dmg"
  echo "==> building $DMG"
  STAGE="$OUT/dmg-stage"; rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  rm -f "$DMG"
  hdiutil create -volname "DevSweep" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  echo "    -> $DMG"
fi

echo "==> done: $APP"

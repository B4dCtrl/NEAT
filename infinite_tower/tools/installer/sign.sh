#!/usr/bin/env bash
# Signs the Windows build with an Authenticode certificate (osslsigncode).
#
# Why: Windows 11's Smart App Control (and SmartScreen) block programs that are
# not signed by a certificate from a trusted authority. Order of the build:
#   1. export the game      -> export/windows/Stairborn.exe (+ .pck)
#   2. sign.sh game         -> signs Stairborn.exe in place
#   3. makensis ...         -> export/Stairborn-Setup.exe
#   4. sign.sh installer    -> signs the installer (and the uninstaller inside it
#                              is signed too when the NSIS build is told to)
#
# Needs a real code-signing certificate (OV/EV from a CA, or Microsoft Artifact
# Signing). A self-signed certificate does NOT satisfy Smart App Control.
#
#   SIGN_PFX=/path/cert.pfx SIGN_PASS=secret tools/installer/sign.sh game|installer
#   (SIGN_URL overrides the timestamp server)
set -euo pipefail
cd "$(dirname "$0")/../.."

what="${1:-}"
: "${SIGN_PFX:?set SIGN_PFX to the .pfx certificate}"
: "${SIGN_PASS:?set SIGN_PASS to its password}"
url="${SIGN_URL:-http://timestamp.digicert.com}"

case "$what" in
  game)      file="export/windows/Stairborn.exe" ;;
  installer) file="export/Stairborn-Setup.exe" ;;
  *) echo "usage: sign.sh game|installer" >&2; exit 2 ;;
esac

tmp="$file.signed"
osslsigncode sign -pkcs12 "$SIGN_PFX" -pass "$SIGN_PASS" \
  -n "Stairborn" -i "https://github.com/b4dctrl/neat" \
  -h sha256 -ts "$url" -in "$file" -out "$tmp"
mv "$tmp" "$file"
osslsigncode verify -in "$file" | head -8

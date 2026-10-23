#!/usr/bin/env bash
# Zip channel/ and sideload it onto the Roku through the dev installer.
#   scripts/deploy.sh              build + install
#   scripts/deploy.sh screenshot   save a screenshot of the TV to build/screen.<ext>
#   scripts/deploy.sh console      stream the BrightScript debug console (port 8085)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.env.local" ] && source "$ROOT/.env.local"
: "${ROKU_IP:?set ROKU_IP in .env.local}"
: "${ROKU_PASS:?set ROKU_PASS in .env.local}"
ROKU_USER="${ROKU_USER:-rokudev}"
BUILD="$ROOT/build"
mkdir -p "$BUILD"

case "${1:-install}" in
  screenshot)
    curl -s -S --digest -u "$ROKU_USER:$ROKU_PASS" -F mysubmit=Screenshot -F passwd= -F archive= \
      "http://$ROKU_IP/plugin_inspect" > "$BUILD/inspect.html"
    img=$(grep -oE 'pkgs/dev\.(jpg|png)' "$BUILD/inspect.html" | head -1)
    [ -n "$img" ] || { echo "no screenshot in response (is the dev channel running?)"; exit 1; }
    ext="${img##*.}"
    curl -s -S --digest -u "$ROKU_USER:$ROKU_PASS" -o "$BUILD/screen.$ext" "http://$ROKU_IP/$img?t=$(date +%s)"
    echo "$BUILD/screen.$ext"
    exit 0 ;;
  console)
    exec nc "$ROKU_IP" 8085 ;;
esac

rm -f "$BUILD/channel.zip"
(cd "$ROOT/channel" && zip -q -r -9 "$BUILD/channel.zip" . -x '*.DS_Store')
echo "packed $(du -h "$BUILD/channel.zip" | cut -f1)"

# leave the current dev channel so the new one launches fresh
curl -s -m 3 -d '' "http://$ROKU_IP:8060/keypress/Home" >/dev/null || true
out=$(curl -s -S --digest -u "$ROKU_USER:$ROKU_PASS" \
        -F mysubmit=Install -F "archive=@$BUILD/channel.zip" \
        "http://$ROKU_IP/plugin_install")
msg=$(echo "$out" | grep -oE "(Install Success|Identical to previous version|Install Failure[^<\"]*|Compilation Failed[^<\"]*)" | head -1)
echo "roku: ${msg:-$(echo "$out" | sed -n 's/.*<font color="red">\([^<]*\).*/\1/p' | head -1)}"
case "$msg" in
  "Install Success"|"Identical to previous version") ;;
  *) echo "$out" | sed 's/<[^>]*>//g' | grep -v '^\s*$' | tail -20; exit 1 ;;
esac
# the installer auto-launches the channel; make sure it's in front
curl -s -m 3 -d '' "http://$ROKU_IP:8060/launch/dev" >/dev/null || true

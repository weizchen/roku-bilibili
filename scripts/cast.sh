#!/usr/bin/env bash
# Play a bilibili video on the TV from this computer.
#   scripts/cast.sh BV1GJ411x7h7
#   scripts/cast.sh "https://www.bilibili.com/video/BV1GJ411x7h7?p=2"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.env.local" ] && source "$ROOT/.env.local"
: "${ROKU_IP:?set ROKU_IP in .env.local}"
bvid=$(echo "${1:?usage: cast.sh <BV id or bilibili url>}" | grep -oE 'BV[0-9A-Za-z]{10}' | head -1)
[ -n "$bvid" ] || { echo "no BV id found in: $1"; exit 1; }
# input reaches a running channel; launch starts it if it isn't in front
if curl -s -m 3 "http://$ROKU_IP:8060/query/active-app" | grep -q 'id="dev"'; then
  curl -s -d '' "http://$ROKU_IP:8060/input?contentId=$bvid&mediaType=movie"
else
  curl -s -d '' "http://$ROKU_IP:8060/launch/dev?contentId=$bvid&mediaType=movie"
fi
echo "casting $bvid -> $ROKU_IP"

#!/usr/bin/env bash
set -euo pipefail

CHANNEL="${1:-stable}"
BASE="https://raw.githubusercontent.com/Streamliner-One/install/main"

if command -v curl >/dev/null 2>&1; then
  FETCH="curl -fsSL"
elif command -v wget >/dev/null 2>&1; then
  FETCH="wget -qO-"
else
  echo "Need curl or wget" >&2
  exit 1
fi

echo "[install] channel: ${CHANNEL}"
VERSIONS="$($FETCH ${BASE}/versions.json)"
URL=$(echo "$VERSIONS" | python3 -c 'import sys,json;d=json.load(sys.stdin);ch=sys.argv[1];print(d["channels"][ch]["artifact_url"])' "$CHANNEL")

echo "[install] downloading artifact..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
$FETCH "$URL" > "$TMP/tools-config-server.tar.gz"

echo "[install] downloaded: $URL"
echo "[install] next: extract and run setup (stub)"

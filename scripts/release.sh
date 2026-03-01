#!/usr/bin/env bash
set -euo pipefail
VER="${1:?Usage: scripts/release.sh <version>}"
jq --arg v "$VER" '.channels.stable.version=$v | .channels.latest.version=$v' versions.json > /tmp/versions.json
mv /tmp/versions.json versions.json
echo "Updated versions.json to $VER"

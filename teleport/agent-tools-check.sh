#!/usr/bin/env bash
set -euo pipefail

# Auto-detect tools server: try localhost first (standard for teleported machines),
# then fall back to the Tailscale address (mel's original setup).
# Override entirely with TOOLS_SERVER_URL env var if needed.
if [ -z "${TOOLS_SERVER_URL:-}" ]; then
  if curl -sk --max-time 3 "https://localhost:8443/api/version" >/dev/null 2>&1; then
    BASE_URL="https://localhost:8443"
  else
    BASE_URL="https://mel.taile54a5b.ts.net:8443"
  fi
else
  BASE_URL="$TOOLS_SERVER_URL"
fi
PASSWORD="${TOOLS_SERVER_PASSWORD:-mel2026}"
COOKIE_FILE="/tmp/tools_server_cookie_$$.txt"
ALL_OK=true

cleanup() { rm -f "$COOKIE_FILE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ── Tools Server ─────────────────────────────────────────────────────────────
if ! curl -sk --max-time 5 -c "$COOKIE_FILE" -X POST "$BASE_URL/api/login" \
  -H 'Content-Type: application/json' \
  -d "{\"password\":\"$PASSWORD\"}" >/dev/null; then
  echo "TOOLS_SERVER_CHECK: FAIL (unreachable at ${BASE_URL} — is tools-config-server.service running?)"
  ALL_OK=false
else
  CREDS_JSON=$(curl -sk --max-time 8 -b "$COOKIE_FILE" "$BASE_URL/api/credentials" || true)
  COUNT=$(printf '%s' "$CREDS_JSON" | jq '.credentials | length' 2>/dev/null || echo 0)
  VER=$(curl -sk --max-time 5 -b "$COOKIE_FILE" "$BASE_URL/api/version" | jq -r '.current.version // "unknown"' 2>/dev/null || echo unknown)
  echo "TOOLS_SERVER_CHECK: OK (version=$VER, credentials=$COUNT)"
fi

# ── Qdrant ───────────────────────────────────────────────────────────────────
QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_STATUS=$(curl -s --max-time 5 "http://localhost:${QDRANT_PORT}/healthz" 2>/dev/null || echo "")
if echo "$QDRANT_STATUS" | grep -qi "ok\|healthy\|passed\|all shards are ready"; then
  # Get vector count
  VECTORS=$(curl -s --max-time 5 "http://localhost:${QDRANT_PORT}/collections/openclaw_memories" 2>/dev/null \
    | jq '.result.vectors_count // .result.points_count // "?"' 2>/dev/null || echo "?")
  echo "QDRANT_CHECK: OK (vectors=$VECTORS)"
else
  echo "QDRANT_CHECK: FAIL (not responding on :${QDRANT_PORT})"
  ALL_OK=false
fi

# ── Neo4j ────────────────────────────────────────────────────────────────────
# HTTP port: non-standard 8474 (mapped from container's 7474)
# Bolt port: 8687 — do NOT check via HTTP, it speaks the bolt protocol only
NEO4J_HTTP_PORT="${NEO4J_HTTP_PORT:-8474}"
NEO4J_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  "http://localhost:${NEO4J_HTTP_PORT}" 2>/dev/null || echo "000")
if [[ "$NEO4J_HTTP_CODE" == "200" || "$NEO4J_HTTP_CODE" == "301" || "$NEO4J_HTTP_CODE" == "302" ]]; then
  echo "NEO4J_CHECK: OK (HTTP :${NEO4J_HTTP_PORT} → ${NEO4J_HTTP_CODE})"
else
  echo "NEO4J_CHECK: FAIL (HTTP :${NEO4J_HTTP_PORT} → ${NEO4J_HTTP_CODE})"
  ALL_OK=false
fi

# ── OpenClaw Gateway ─────────────────────────────────────────────────────────
# Try as current user first, then fall back to checking the process
GATEWAY_STATUS=""
if command -v systemctl >/dev/null 2>&1; then
  GATEWAY_STATUS=$(systemctl --user is-active openclaw-gateway 2>/dev/null || \
    XDG_RUNTIME_DIR="/run/user/$(id -u)" systemctl --user is-active openclaw-gateway 2>/dev/null || \
    echo "unknown")
fi

if [[ "$GATEWAY_STATUS" == "active" ]]; then
  echo "GATEWAY_CHECK: OK (systemd active)"
elif pgrep -f "openclaw.*gateway\|openclaw-gateway" >/dev/null 2>&1; then
  echo "GATEWAY_CHECK: OK (process running)"
else
  echo "GATEWAY_CHECK: FAIL (not running)"
  ALL_OK=false
fi

# ── Summary ──────────────────────────────────────────────────────────────────
if $ALL_OK; then
  echo "ALL_GREEN: true"
else
  echo "ALL_GREEN: false"
fi

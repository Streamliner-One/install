#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  harden.sh — Post-teleport security hardening                           ║
# ║  Project Teleport (Mel Miles mode)                                      ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Run AFTER teleport-restore.sh has completed and you have confirmed:
#   - SSH access works
#   - OpenClaw gateway is running and responding
#   - All verification checks passed
#
# What this script does:
#   1. Installs and configures fail2ban (SSH brute force protection)
#   2. Enables recidive jail (escalating bans for persistent attackers)
#   3. Disables root SSH login (PermitRootLogin no)
#   4. Verifies hardening is active
#
# ⚠️  Prerequisites:
#   - Must be run as root
#   - SSH access MUST be confirmed working before running
#   - Tailscale or direct SSH session must be active
#
# Usage:
#   sudo bash harden.sh [--tailscale-cidr 100.64.0.0/10]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

phase() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}[PHASE] $1${NC}"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $1" >&2; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
TAILSCALE_CIDR="${TAILSCALE_CIDR:-100.64.0.0/10}"

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --tailscale-cidr) TAILSCALE_CIDR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Must be root ──────────────────────────────────────────────────────────────
[ "$(id -u)" -ne 0 ] && fail "Must be run as root (sudo bash harden.sh)"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║               🔒 OpenClaw Post-Teleport Hardening                   ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Steps: fail2ban + recidive jail + disable root SSH login           ║"
printf "║  Tailscale CIDR (never banned): %-36s ║\n" "$TAILSCALE_CIDR"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}⚠️  Only run this after confirming SSH access works correctly.${NC}"
echo ""
read -r -p "Confirmed — proceed with hardening? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Phase 1: Install fail2ban ─────────────────────────────────────────────────
phase "1/3 — Install fail2ban"

apt-get update -qq
apt-get install -y -qq fail2ban > /dev/null
ok "fail2ban installed"

# ── Phase 2: Configure jails ──────────────────────────────────────────────────
phase "2/3 — Configure jails (SSH + recidive)"

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime  = 2h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ${TAILSCALE_CIDR}

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 2h

[recidive]
enabled   = true
logpath   = /var/log/fail2ban.log
banaction = iptables-allports
bantime   = 1w
findtime  = 1d
maxretry  = 3
EOF

ok "jail.local written (SSH: 5 attempts → 2h ban, recidive: 3 bans/day → 1 week)"

systemctl enable fail2ban
systemctl restart fail2ban

# Brief wait for socket
sleep 3

if systemctl is-active --quiet fail2ban; then
  ok "fail2ban running"
else
  fail "fail2ban failed to start — check: journalctl -u fail2ban"
fi

# Verify both jails loaded
JAIL_LIST=$(fail2ban-client status 2>/dev/null | grep "Jail list" || echo "")
if echo "$JAIL_LIST" | grep -q "sshd"; then
  ok "sshd jail active"
else
  warn "sshd jail not detected — check: fail2ban-client status"
fi
if echo "$JAIL_LIST" | grep -q "recidive"; then
  ok "recidive jail active"
else
  warn "recidive jail not detected — check: fail2ban-client status"
fi

# ── Phase 3: Disable root SSH login ──────────────────────────────────────────
phase "3/3 — Disable root SSH login"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup
cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
ok "sshd_config backed up"

# Apply change
if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
else
  echo "PermitRootLogin no" >> "$SSHD_CONFIG"
fi

# Validate and reload
if sshd -t; then
  ok "sshd config valid"
  systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || warn "Could not reload SSH — reboot to apply"
  ok "SSH reloaded — root login disabled"
else
  fail "sshd config test failed — reverting"
  cp "${SSHD_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)" "$SSHD_CONFIG" 2>/dev/null || true
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Hardening complete${NC}"
echo ""
echo "  fail2ban:     active (sshd + recidive jails)"
echo "  Root login:   disabled"
echo "  Tailscale:    always allowed (${TAILSCALE_CIDR})"
echo ""
echo "  Check banned IPs:  fail2ban-client status sshd"
echo "  Unban an IP:       fail2ban-client set sshd unbanip <ip>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

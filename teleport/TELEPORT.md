# Project Teleport

> Deploy or replicate the full OpenClaw + Mem0 self-hosted stack to any machine.

---

## 🚀 Running a Restore (Mel Miles mode)

### What you need before starting

| Item | Where to find it |
|------|-----------------|
| Backup archive (`.tar.gz.gpg`) | Google Drive folder ID: `1vK0OpxQypj9IhZecECcEpxFFbpkULeXN` — download the latest `openclaw-backup-YYYY-MM-DD.tar.gz.gpg` to the target server first (`scp` or `wget`) |
| Backup decryption key | **Primary:** `~/.openclaw/.backup-key` on current mel (copy via `scp`)<br>**Emergency:** 1Password → item **"OpenClaw Backup Key"** → password field |
| GitHub token | 1Password → item **"github"** → token field |
| Telegram bot token | `~/.openclaw/openclaw.json` → `channels.telegram.token` on current mel, or create a fresh bot via @BotFather |

> ⚠️ **Key warning:** Never run `backup-mem0.sh` with an unverified key. If the key changes, all prior archives become undecryptable. The 1Password item is the emergency copy — keep it current.

### Transferring the backup and key to the target server

```bash
# From your local machine or current mel — copy backup archive + key
scp /tmp/openclaw-backup-2026-MM-DD.tar.gz.gpg root@<target-ip>:/root/
scp ~/.openclaw/.backup-key root@<target-ip>:/root/.backup-key
```

> The backup archives live at `/tmp/openclaw-backup-YYYY-MM-DD.tar.gz.gpg` on the source machine.

### The command

```bash
bash teleport-restore.sh \
  --backup /root/openclaw-backup-YYYY-MM-DD.tar.gz.gpg \
  --key-file /root/.backup-key \
  --github-token <token-from-1password> \
  --user alex \
  --telegram-token <bot-token>
```

### After the script finishes (3 steps only)

1. **Message your bot** on Telegram → you'll get a pairing request code. Then SSH as `alex` and approve:
   ```bash
   /home/alex/.npm-global/bin/openclaw pairing approve telegram <CODE>
   ```
   > ⚠️ `openclaw` is not in PATH by default after restore — use the full path above.

2. **Verify tools server credentials restored** — open `https://<server>:8443` in browser, log in with the restore password. You should see all integrations listed (Anthropic, Telegram, etc.). If empty, the backup lacked `tools-registry.json` — re-enter credentials manually via the dashboard.
   > As of 2026-03-14 the backup correctly includes `tools-server-data/tools-registry.json` (36 credentials). Older backups (pre-2026-03-14) will NOT have this and require manual credential re-entry.

3. **Verify** the agent responds in Telegram with a real model reply. Then harden:
   ```bash
   bash ~/.openclaw/workspace/streamliner/teleport/harden.sh
   ```

> If you passed `--telegram-token`, the gateway starts automatically.
> If not, update `~/.openclaw/openclaw.json` → `channels.telegram.token`, then `systemctl --user start openclaw-gateway`.

---

## What It Is

Teleport is the mechanism for moving or cloning the entire Streamliner assistant stack — OpenClaw runtime, Mem0 (Qdrant + Neo4j), Tools Config Server, hooks, cron jobs, and agent identity — onto a new machine. It has two modes:

| Mode | Use case | Includes memories? | Includes credentials? |
|------|----------|-------------------|----------------------|
| **Mel Miles** | Alex's own machines (new VPS, Mac Mini, etc.) | ✅ Yes (full restore) | ✅ Yes (encrypted) |
| **Client installs** | New client deployments | ❌ No | ❌ No (they add their own) |

---

## Architecture: Four Layers

| Layer | Contents |
|-------|----------|
| **Software** | OpenClaw, Tools Config Server, Docker images (Qdrant, Neo4j) |
| **Configuration** | `openclaw.json`, credentials, hooks, cron, systemd |
| **Personal data** | Qdrant vectors, Neo4j graph, SQLite history, workspace files |
| **Identity** | `SOUL.md`, `IDENTITY.md`, `USER.md`, `AGENTS.md`, `HEARTBEAT.md`, `TOOLS.md` |

Mel Miles restores all four. Client installs deliver layer 1 only, then guide the client through layers 2–4.

---

## Delivery URLs

| Component | URL | Status |
|-----------|-----|--------|
| Tools Config Server installer | `curl https://tools.streamliner.one \| bash` | ✅ Live |
| Full stack installer (Teleport) | `curl https://teleport.streamliner.one \| bash` | 🔲 Not yet |

---

## Script Inventory

| Script | Location | Status | Purpose |
|--------|----------|--------|---------|
| `install.sh` | `Streamliner-One/tools` → `tools.streamliner.one` | ✅ Done | Installs Tools Config Server |
| `teleport-restore.sh` | `teleport/` folder (local only) | 🟡 Draft (468 lines) | Mel Miles full restore — needs phase 9.5 (tools server install) wired in |
| `setup-client.sh` | — | 🔲 Not built | Parameterized clean install for clients |
| `fire-drill.sh` | — | 🔲 Not built | Automated test cycle on fresh VPS |

### Script sequencing (full stack)
```
base deps → OpenClaw → Mem0 stack (Qdrant + Neo4j) → restore data
  → tools server install [phase 9.5, missing] → agent config → verify
```

---

## Phase Status

### ✅ Phase 1 — Tools Server delivery (COMPLETE)
- GitHub repo renamed `Streamliner-One/install` → `Streamliner-One/tools`
- Netlify domain `install.streamliner.one` → `tools.streamliner.one`
- `curl https://tools.streamliner.one | bash` live and serving `application/x-sh`
- All URL references updated across `tools`, `tools-packages`, `tools-config-server`
- 33/33 integrations healthy post-install

### 🟡 Phase 2 — Full stack installer (IN PROGRESS)
- `teleport-restore.sh` drafted, covers phases 1–10 for Mel Miles mode
- ✅ Phase 9.5 (tools server install) wired in — installs and starts tools-config-server
- ✅ `auth-profiles.json` now included in backup + correctly restored (fixed 2026-03-13)
- ✅ `tools-registry.json` (all credentials + intent rules) now included in backup + correctly restored (fixed 2026-03-14)
- ✅ Check script URL fixed: uses `localhost:8443` not hardcoded Tailscale address
- ✅ Gateway now starts (not just enables) after restore
- ✅ Tools server credentials now backed up and auto-restored — no longer a gap
- Missing: GitHub repo, Netlify site, delivery URL
- Client path (`setup-client.sh`) not started

**Live drill result (2026-03-13):** Full restore succeeded on Contabo VPS. Agent responded via Telegram with real model replies. Manual steps required: download backup from Drive, fetch key from 1Password, approve pairing via SSH, re-enter tools server credentials. Restore time ~15 min.

### 🔲 Phase 3 — Client installer
- Parameterized templates
- `setup-client.sh` — guided onboarding, no personal data

### 🔲 Phase 4 — Fire drills
- `fire-drill.sh` — spin up fresh VPS, run full install, verify, destroy

---

## What Needs To Be Done (Manually)

### GitHub (Alex does this)
1. Create new **public** repo: `Streamliner-One/teleport`
   - Public so the install script is fetchable without auth
   - Description: *"Full-stack OpenClaw + Mem0 installer — Project Teleport"*
   - Initialize with README (will be replaced)

### Netlify (Alex does this)
2. Create new Netlify site from `Streamliner-One/teleport` repo
   - Site serves the root file (same pattern as `tools.streamliner.one`)
   - Add custom domain: `teleport.streamliner.one`
3. Add DNS record in Netlify DNS:
   - Type: `CNAME`, Name: `teleport`, Value: `<new-netlify-site>.netlify.app`

### Then Mel takes over
4. Push `teleport-restore.sh` (renamed to entry script) to the new repo
5. Wire in phase 9.5 (tools server install)
6. Test end-to-end

---

---

## ⚠️ Known Gaps & Lessons Learned (from 2026-03-13 live drill)

### 1. Tools Server Credentials — ✅ FIXED (2026-03-14)
~~The Tools Config Server stores credentials in its own SQLite DB — not included in backup.~~

The tools server now stores credentials in `tools-registry.json` (JSON, not SQLite). This file is backed up to `tools-server-data/tools-registry.json` in the archive and restored to `~/workspace/tools-registry.json` on the target machine. All 36 credentials and intent/behavior rules are preserved.

> **Note:** Backups created before 2026-03-14 do NOT include this file. If restoring from an older archive, re-enter credentials manually via the dashboard at `https://<server>:8443`.

### 2. auth-profiles.json — Wrong Path
`auth-profiles.json` (all API keys for models: Anthropic, OpenAI, Moonshot, etc.) lives at:
```
~/.openclaw/agents/main/agent/auth-profiles.json
```
The backup script was referencing `~/.openclaw/auth-profiles.json` (wrong). Fixed 2026-03-13 in `backup-mem0.sh` and `teleport-restore.sh`. Without this file, the agent starts but cannot call any AI model.

### 3. `openclaw` Not in PATH After Restore
After restore, the `openclaw` binary is at `/home/alex/.npm-global/bin/openclaw` but not in the `alex` user's PATH during SSH sessions. Always use the full path:
```bash
/home/alex/.npm-global/bin/openclaw pairing approve telegram <CODE>
```

### 4. Pairing Required After Every Restore
By design, a new bot token triggers a fresh pairing request. After restore you must:
1. Message the bot from Telegram
2. SSH as `alex` and approve the pairing code

This is a one-time step per restore. The pairing is then persistent.

### 5. better-sqlite3 Recompile
If Node.js version on the new machine differs from the source machine, `better-sqlite3` (used by the tools server) may fail with a binding error. Fix:
```bash
cd ~/.openclaw/workspace/tools-server
npm rebuild better-sqlite3
```

### 6. scp Is the Correct Transfer Method
For ad-hoc file transfers to the restore target (e.g. auth-profiles.json), use `sshpass + scp`. Not rsync, not sftp wrappers.

---

## Backup
- Nightly backup capsule (~1.2MB) generated and uploaded to Google Drive
- Script: `~/.openclaw/backup-mem0.sh`
- Payload: Qdrant snapshot + Neo4j export + `openclaw.json` + `auth-profiles.json` (fixed 2026-03-13) + hooks, encrypted with AES256 GPG

### What IS in the backup
| Item | Notes |
|------|-------|
| Qdrant vector snapshot | All Mem0 memories |
| Neo4j graph export | Relationship graph |
| `openclaw.json` | Full config incl. model keys, bot token |
| `auth-profiles.json` | OAuth tokens for all AI models (Anthropic, OpenAI, Moonshot…) |
| `tools-registry.json` | All 36 credentials + intent/behavior rules (added 2026-03-14) |
| Workspace files | `memory/`, `contacts/`, `travel.json`, etc. |
| Hooks + cron scripts | `backup-mem0.sh`, `health-watchdog.sh`, etc. |
| Extensions | `openclaw-mem0`, `lossless-claw`, etc. |

### What's NOT in the backup (gaps)
| Item | Impact | Fix status |
|------|--------|-----------|
| Google OAuth tokens (`gog` credentials) | Re-auth required for Google Workspace (`gog`) after restore | ❌ Not yet |
| WhatsApp session | Re-link required | By design |
| Cognee Docker volumes | Knowledge graph rebuild needed after restore | ❌ Not yet |

---

*Last updated: 2026-03-13 (post live drill)*

# install

One-line installer and release manifests for [tools-config-server](https://github.com/Streamliner-One/tools-config-server).

## Install

```bash
curl https://install.streamliner.one | bash
```

Sets up Node.js, downloads the server, installs dependencies, creates a systemd service, and prints your access URL and password. Tested on Ubuntu 22.04 / 24.04.

## What gets installed

→ [tools-config-server](https://github.com/Streamliner-One/tools-config-server) — self-hosted credential vault, OAuth re-auth, service health dashboard, live query runner, and TOOLS.md generator for AI agent infrastructure.

## Channels

| Channel | Version |
|---------|---------|
| `stable` | 0.6.0 |
| `latest` | 0.6.0 |

Channel manifest: [`versions.json`](./versions.json)

## Manual channel selection

```bash
curl https://install.streamliner.one | bash -s -- --channel latest
```

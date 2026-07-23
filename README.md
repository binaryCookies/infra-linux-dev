# infra-linux-dev

Infrastructure orchestration for the Linux dev server.

Reverse-proxy source of truth is managed in this repository under `reverse-proxy/`.

## Scope

This repository contains lightweight infrastructure controls for:
- Docker network initialization
- SSL service lifecycle
- Reverse proxy lifecycle
- Basic diagnostics and chatbot path checks

## Quick Start

```bash
# from this directory
make init
make ssl-up
make proxy-up
make diagnose
```

## Secure Runtime Checks

`chatbot-check` requires runtime credentials via environment variables:

```bash
CHATBOT_TEST_EMAIL="you@example.com" \
CHATBOT_TEST_PASSWORD="your-password" \
make chatbot-check
```

No real credentials or secrets should be committed to this repository.

## Core Targets

- `make init`
- `make status`
- `make deploy-all`
- `make down-all`
- `make ssl-up`
- `make proxy-up`
- `make diagnose`
- `make recover-chatbot`

## Notes

- Update `.env` to `.env-infra` allowing simpler future CLI searches, keep untracked.
- Keep certificate/private key files out of git.
- Treat `/etc/apache2` and `/etc/nginx` as runtime state; manage canonical proxy config from this repository.
- Use this repo only for infrastructure concerns; application code lives in separate repositories.

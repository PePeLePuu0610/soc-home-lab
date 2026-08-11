# Docker Compose Files

| Folder | Stack | UI port(s) | Vendored here? |
|---|---|---|---|
| `openvas/` | Greenbone Community Edition (OpenVAS) — vulnerability scanning | 9392 | **No** — README points at Greenbone's live official file, which changes structure more often than most (see that folder's README for why) |
| `thehive/` | TheHive + Cortex — SOAR case management and automated response | 9000 (TheHive), 9001 (Cortex) | Yes — vendored `docker-compose.yml` in this repo |

## Before running either stack

- Install Docker Engine on the Ubuntu Server VM you're using for that component (see Phase 1's ISO/software checklist).
- For TheHive: copy `.env.example` to `.env` inside `thehive/` and set real values there — `.env` is git-ignored on purpose, never commit real passwords or secrets. After both containers are up, generate a Cortex API key in the Cortex UI, then paste it into `thehive/thehive/application.conf` (`cortex.servers[0].auth.key`) and restart the `thehive` container so the two are connected.
- For OpenVAS: follow the setup steps in `openvas/README.md` — it pulls Greenbone's current official compose file directly rather than a copy stored here.

## Running the TheHive/Cortex stack

```bash
cd configs/docker-compose/thehive
docker compose up -d
```

This is a single-node, unencrypted lab configuration — not production-ready as-is (no TLS, no clustering, minimal resource tuning, and it uses TheHive's local-database fallback instead of the Cassandra/MinIO backend StrangeBee ships for production). Treat it as a starting point to tune once the base build is working, per Phase 3 of the project plan.

## A note on version pinning

Image tags in `thehive/docker-compose.yml` were verified current as of **2026-08-10**. SOAR/security tooling images move fast — before your first deployment, it's worth a quick check against the source links in that file's header comments to confirm nothing's moved again since.

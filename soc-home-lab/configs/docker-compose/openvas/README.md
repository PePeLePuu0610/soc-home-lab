# Greenbone Community Edition (OpenVAS)

**This stack is intentionally not vendored as a static file here.** Greenbone
updates their Community Edition compose architecture more often than most —
verified via search on 2026-08-10, they recently renamed the reference file
from `docker-compose.yml` to `compose.yaml` and added an nginx/TLS front end
to the container layout. Keeping a hand-copied version in this repo would go
stale and could quietly break your build.

## Setup

Pull the current, official file directly at build time:

```bash
mkdir -p ~/greenbone-ce && cd ~/greenbone-ce
curl -f -L https://greenbone.github.io/docs/latest/_static/compose.yaml -o compose.yaml
docker compose -p greenbone-community-edition pull
docker compose -p greenbone-community-edition up -d
```

Full setup guide (architecture, container roles, first-run steps):
https://greenbone.github.io/docs/latest/22.4/container/index.html

## What to expect

- First run downloads vulnerability feed data (NVTs, CERT-Bund, CVE data) —
  this can take 30–60+ minutes depending on your connection. Let it finish
  before running your first scan (`docker compose logs -f` to watch progress).
- Default UI: `https://<VM-IP>:9392` (recent versions default to HTTPS with a
  self-signed cert — expect a browser warning on first visit).
- Default login is `admin` — Greenbone's guide has you set a real password
  during first-run configuration. Change it immediately; don't leave the
  default in place even in a lab.

## Before committing anything from this stack

If you export scan configs, scripts, or anything else from your running
instance into this folder, strip any real credentials or scan target IPs you
don't want public before pushing.

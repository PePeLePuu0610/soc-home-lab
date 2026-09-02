# Build Guide: OpenVAS (Greenbone Community Edition) VM (Step 3.8)

**VM name:** `SOC-Vuln-OpenVAS` · **Zone:** Management · **IP:** `10.10.10.12` · **Specs:** 6GB RAM / 2 vCPU / 40GB disk (actual — more RAM than originally planned)

This guide covers building the OpenVAS/Greenbone vulnerability scanning VM from your Ubuntu 24.04 LTS template, as part of [Phase 3 — Implementation](phase-3-implementation.md). Docker install steps were verified against Docker's current official documentation. The Greenbone stack itself is deliberately **not vendored** as a static compose file in this repo — see [`configs/docker-compose/openvas/README.md`](https://github.com/PePeLePuu0610/soc-home-lab/blob/main/configs/docker-compose/openvas/README.md) for why — this guide fetches Greenbone's live official file at build time instead.

## Before you start

**RAM check.** With Pod A (pfSense + Windows victim + Wazuh, ~10GB) plus ELK (**4GB actual**) and Splunk (6GB) already running, you're at ~20GB. Adding OpenVAS (**6GB actual**) brings you to ~26GB, leaving ~6GB for the Windows host itself — better headroom than originally planned, since ELK ended up needing less RAM than expected even though OpenVAS needed more. Still, if the host feels sluggish while OpenVAS's first-run feed download is chewing through CPU/disk (see 3.8.4), it's fine to temporarily power off ELK or Splunk until the build is done. Neither is doing active work for this step.

## 3.8.1 — Clone the VM

Same process as the SIEM builds: clone the Ubuntu 24.04 LTS template → name `SOC-Vuln-OpenVAS` → `E:\PePesLab-SOC 2.0\VMz\SOC-Vuln-OpenVAS` → **Memory 6144 MB, Processors 2, Network: VMnet1 (Management)**.

## 3.8.2 — Configure networking and update the OS

Same pattern as [ELK's 3.6.2](build-elk-stack.md#362-configure-networking-and-update-the-os), but use address `10.10.10.12/24` and hostname `SOC-Vuln-OpenVAS`.

## 3.8.3 — Install Docker Engine

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Let your own user run `docker` without `sudo` every time (optional but convenient):

```bash
sudo usermod -aG docker $USER
```

**Log out and back in** for that group change to take effect — it won't apply to your current session.

```bash
docker run hello-world
```

If that prints a "Hello from Docker!" message, the install is good.

## 3.8.4 — Deploy Greenbone Community Edition

```bash
mkdir -p ~/greenbone-ce && cd ~/greenbone-ce
curl -f -L https://greenbone.github.io/docs/latest/_static/compose.yaml -o compose.yaml
docker compose -p greenbone-community-edition pull
docker compose -p greenbone-community-edition up -d
```

**This takes a while — plan for 30–60+ minutes.** The first run downloads Greenbone's full vulnerability feed data (NVTs, CERT-Bund advisories, CVE data), which is a large amount of data over a slow connection. Watch progress with:

```bash
docker compose -p greenbone-community-edition logs -f
```

Don't interrupt it partway through — a partial feed sync can leave the scanner in a broken state that's easier to fix by letting it finish than by restarting mid-download.

**Fix the web UI's port binding before trying to log in — this step is easy to miss and the default will silently block remote access.** Greenbone's official compose file binds its `nginx` front-end (the actual web UI / TLS endpoint) to `127.0.0.1` only — reachable from inside the VM itself, not from your Windows host, regardless of firewall rules. This is a deliberate security default in Greenbone's compose file, not a bug, but it needs changing for this lab's use case:

```bash
nano compose.yaml
```

Find the `nginx:` service block. Under its `ports:` section, change:

```yaml
    ports:
      - 127.0.0.1:443:443
      - 127.0.0.1:9392:9392
```

to:

```yaml
    ports:
      - 443:443
      - 9392:9392
```

Save (`Ctrl+O`, `Enter`, `Ctrl+X`), then recreate the containers so the new port mapping takes effect — a restart alone won't pick up a port binding change, only a full recreate will:

```bash
docker compose -p greenbone-community-edition down
docker compose -p greenbone-community-edition up -d
```

This doesn't touch your feed data — `down` without `-v` only removes containers, not the volumes holding everything you already downloaded.

## 3.8.5 — First login

Once containers are back up:

1. Browse to `https://10.10.10.12` from your Windows host browser — **no port number**. Port 443 is HTTPS's default, so you don't need to type it; port 9392 is just a plain-HTTP redirector to 443, not a TLS endpoint itself, so don't use `https://` with `:9392` — that combination fails with a confusing "wrong version number" TLS error. Expect a **"Not secure"** browser warning either way — Greenbone's self-signed certificate is expected in a lab, not an error.
2. Log in with username `admin`. Greenbone's first-run flow has you set a real password immediately — **do this now**, don't leave a default password in place even in a lab.

## 3.8.6 — Run your first scan

1. In the Greenbone UI, go to **Configuration → Targets → New Target**. Name it `Windows Victim`, host `10.10.20.20` (your Corp-zone Windows victim VM).
2. Go to **Scans → Tasks → New Task**. Name it `Windows Victim Baseline Scan`, select the target you just created, use the default **Full and fast** scan config to start.
3. Start the task and let it run — a first scan against a single host typically takes anywhere from several minutes to an hour depending on scan config and how much of the feed has finished syncing.
4. **Confirm:** once complete, the task produces a **Report** with findings (even a clean Windows install usually surfaces a handful of informational or low-severity items) — that report is your Phase 1 success criterion for vulnerability management.

## 3.8.7 — Snapshot and sign off

In VMware: **VM → Snapshot → Take Snapshot** → name it `OpenVAS working baseline`.

### Exit criteria for Step 3.8

- [ ] VM built, static IP `10.10.10.12`, hostname set
- [ ] Docker Engine installed and verified with `hello-world`
- [ ] Greenbone Community Edition containers running, feed sync completed
- [ ] Logged into Greenbone Web UI, default `admin` password changed
- [ ] Target and task created against the Windows victim VM
- [ ] Scan completed, report generated with findings
- [ ] Snapshot taken

## Troubleshooting

- **`curl`/browser TLS error like "wrong version number" when hitting `:9392` over HTTPS:** port 9392 is a plain-HTTP redirector to port 443, not a TLS endpoint. Use `https://10.10.10.12` (no port, or explicit `:443`) instead — see 3.8.4's port-binding step above.
- **Can't reach the UI at all, even though `docker compose ps` shows everything healthy:** almost certainly the default `127.0.0.1`-only port binding on the `nginx` service — see the fix in 3.8.4. This is the single most common blocker on this build, since every container can be perfectly healthy while the UI is still unreachable from outside the VM.
- **UI loads but scan configs/feeds look empty or greyed out:** the feed sync from 3.8.4 likely hasn't finished yet. Check `docker compose -p greenbone-community-edition logs -f` for ongoing feed-update activity before assuming something's broken.
- **`docker: permission denied` errors:** you ran a `docker` command without `sudo` before logging out/in after the `usermod -aG docker` step. Either log out and back in, or prefix commands with `sudo` in the meantime.
- **Containers keep restarting or exiting:** check disk space with `df -h` first — the feed data is large, and a nearly-full 40GB disk can starve the containers partway through sync.
- **Can't reach `https://10.10.10.12:9392` at all:** confirm the containers are actually up with `docker compose -p greenbone-community-edition ps` — all should show `running` or `healthy`, not `exited`.

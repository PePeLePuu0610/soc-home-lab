# Build Guide: Splunk Enterprise VM (Step 3.7)

**VM name:** `SOC-SIEM-Splunk` · **Zone:** Management · **IP:** `10.10.10.14` · **Specs:** 6GB RAM / 2 vCPU / 60GB disk

This guide covers building the Splunk Enterprise VM from your Ubuntu 24.04 LTS template, as part of [Phase 3 — Implementation](phase-3-implementation.md). It's built as a second, permanent SIEM alongside ELK for direct side-by-side comparison — see the IP address note in [Phase 2 — Design](phase-2-design.md#22-vm-inventory-ip-address-plan) for why that changed the original one-shared-address plan.

## Before you start

**RAM check:** with Pod A running (pfSense + Windows victim + Wazuh, ~10GB) plus ELK (**4GB actual**) and Splunk (6GB), you're at roughly 20GB — comfortably inside 32GB with plenty of headroom for the host OS. No need to power anything off to build this alongside ELK.

Like ELK, this VM sits on the Management zone, so you can browse Splunk Web directly from your Windows host browser once it's built.

## 3.7.1 — Clone the VM

Same process as the ELK build: clone the template → name `SOC-SIEM-Splunk` → `E:\PePesLab-SOC 2.0\VMz\SOC-SIEM-Splunk` → **Memory 6144 MB, Processors 2, Network: VMnet1 (Management)**.

## 3.7.2 — Configure networking and update the OS

Same as [ELK's 3.6.2](build-elk-stack.md#362-configure-networking-and-update-the-os), but use address `10.10.10.14/24` and hostname `SOC-SIEM-Splunk`.

## 3.7.3 — Download Splunk (account-gated — do this step yourself)

1. On your Windows host browser, go to `splunk.com` and create a free account if you don't have one (a separate login from Splunk itself — this is just for downloads).
2. Go to **Free Trials & Downloads → Splunk Enterprise → Get My Free Trial**.
3. Select **Linux**, package type **.deb**.
4. Instead of the direct download button, click **"Download via Command Line (wget)"** — it generates a signed `wget` command tied to your login session. Copy it. Splunk's download links are session-signed and expire, and a fixed version number here would go stale — this deliberately isn't hardcoded, use whatever the site gives you at the time you build this.
5. Paste and run that copied command on the Splunk VM to download the `.deb` file.

## 3.7.4 — Install Splunk

```bash
sudo dpkg -i splunk-*.deb
```

**Do not run `splunk start` as root.** Recent Splunk Enterprise releases have deprecated running as root — it will print a deprecation notice and silently refuse to actually start (checking `splunk status` afterward will show "not running," with nothing listening on port 8000). Create a dedicated service account instead and run under that from the start:

```bash
sudo groupadd splunk
sudo useradd -m -g splunk -d /opt/splunk -s /bin/bash splunk
sudo chown -R splunk:splunk /opt/splunk
sudo -u splunk /opt/splunk/bin/splunk start --accept-license
```

Follow the prompts to create your **admin username and password — write these down**, you'll need them for every login going forward.

Register it with systemd so it starts on boot and shows up in normal service listings:

```bash
sudo /opt/splunk/bin/splunk enable boot-start -user splunk -systemd-managed 1 --accept-license --answer-yes --no-prompt
sudo /opt/splunk/bin/splunk status      # should now report splunkd is running, with a PID
sudo ss -tunlp | grep 8000              # confirm Splunk Web is listening
```

## 3.7.5 — Configure a receiving port

For forwarders you'll wire up in Phase 4 (Testing): in Splunk Web, go to **Settings → Forwarding and receiving → Configure receiving → New Receiving Port → 9997 → Save**.

## 3.7.6 — Verify

Browse to `http://10.10.10.14:8000` from your Windows host browser, log in with the admin credentials you created.

## 3.7.7 — Snapshot and sign off

**VM → Snapshot → Take Snapshot** → name it `Splunk working baseline`.

### Exit criteria for Step 3.7

- [ ] VM built, static IP `10.10.10.14`, hostname set
- [ ] Dedicated `splunk` service account created, owns `/opt/splunk`
- [ ] Splunk installed, `splunk start` completed as the `splunk` user, admin credentials created
- [ ] Boot-start enabled via systemd, `splunk status` reports running
- [ ] Receiving port 9997 configured
- [ ] Splunk Web reachable at `http://10.10.10.14:8000`, login successful
- [ ] **Log sources not yet wired up? That's expected here** — see [Configure Log Forwarding](configure-log-forwarding.md) for Wazuh/pfSense/Suricata, done as its own step once both SIEMs exist
- [ ] Snapshot taken

## Troubleshooting: Splunk Web unreachable, service missing from `systemctl`

1. **Check with Splunk's own status command first, not systemd:** `sudo /opt/splunk/bin/splunk status`. Splunk doesn't always register as a native systemd unit unless boot-start was explicitly configured with `-systemd-managed 1`, so its absence from `systemctl list-units` doesn't by itself mean it isn't running.
2. **If `splunk start` printed a deprecation notice and returned to the prompt with no further output** — that's Splunk refusing to start as root, not a warning you can ignore. Follow the dedicated-user steps in 3.7.4 above.
3. `ps aux | grep splunkd` — confirms whether the daemon process is actually alive.
4. `sudo ss -tunlp | grep -E '8000|8089'` — confirms whether anything is listening on Splunk's ports at all.
5. `sudo tail -100 /opt/splunk/var/log/splunk/splunkd.log` — the real error, if there is one, is in here.
6. `df -h` — as with Elasticsearch, a nearly-full disk can prevent Splunk from finishing its first-run initialization.
7. `sudo ufw status` — Ubuntu Server doesn't enable this by default, but if it's active it can block port 8000 even with Splunk running fine locally.

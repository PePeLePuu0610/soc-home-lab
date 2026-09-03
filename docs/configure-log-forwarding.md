# Configure Log Forwarding: Wazuh, pfSense, Suricata, OpenVAS, and Windows → ELK and Splunk

**Completes:** Step 3.6.3 (ELK log sources) and Step 3.7.3 (Splunk log sources), deliberately done *after* both SIEMs and OpenVAS were already built — this is a return trip per Waterfall discipline: don't move on to SOAR (3.9) until the SIEMs are actually receiving data, since SOAR's entire job is acting on alerts that need to already be flowing in. See [ELK Ingestion Plan](elk-ingestion-plan.md) for the objectives/sequencing/exit-gate view of this same work.

This is the most integration-heavy step in the build so far — five log sources, two destinations. Every method below was checked against current documentation rather than older tutorials, because this specific integration has a lot of stale advice floating around that breaks on current versions. Parts 1-4 (Wazuh, pfSense, Suricata) cover both ELK and Splunk; Parts 5-6 (OpenVAS, Windows) currently cover ELK only — Splunk equivalents are noted as follow-up work.

## Before you start: the design decisions that shape everything below

**Wazuh forwards via its own native syslog output, not Filebeat.** An earlier version of this guide had Wazuh's manager run a second Filebeat pointed at the external ELK stack — that turned out to be a bad idea for two reasons found while actually running it: at the time, the Wazuh manager was deployed from **Wazuh's official OVA appliance** (Amazon Linux 2023, hence `yum` rather than `apt` — different from every other VM in this lab, which is why that difference wasn't visible until hitting it directly), and more importantly, **that appliance already ran its own Filebeat**, shipping alerts to Wazuh's own built-in indexer and dashboard as part of its pre-packaged setup. Editing that file would have broken Wazuh's own UI to fix an unrelated problem. **The OVA has since been retired** — Wazuh was rebuilt from scratch on Ubuntu 24.04, matching every other Linux VM in the lab, after the OVA's differences caused enough friction across multiple build steps to justify starting over on a consistent base. The reasoning for using native `syslog_output` instead of a second Filebeat still holds regardless: Wazuh's own install script may still set up its own internal Filebeat+indexer on any OS if you used the all-in-one deployment method, so this guide continues to avoid touching that file either way. Instead, it uses Wazuh's built-in `<syslog_output>` feature in `ossec.conf` — a native manager capability, unrelated to Filebeat, that forwards alerts via syslog to any target you specify.

**Suricata's full EVE JSON output to syslog is unreliable** — several current pfSense forum threads document it simply not working in some package versions. The **"Send Alerts to System Log" checkbox**, however, is confirmed working and is what this guide uses. Trade-off: you get Suricata's alert summaries (source/destination, signature, severity), not full packet payload detail. That's enough for this lab's detection/response goals; if you want full EVE JSON richness later, look into the community [pfELK project](https://github.com/pfelk/pfelk), which adds a `syslog-ng` package specifically for that.

**Every source gets its own port.** Rather than trying to distinguish sources by parsing message content (fragile), Wazuh, and pfSense/Suricata each forward to a *different* port on each SIEM. That makes routing to the correct index/sourcetype deterministic instead of pattern-matching guesswork.

**Non-privileged ports throughout.** Your Splunk service already runs as a dedicated non-root `splunk` user (from the Step 3.7 root-deprecation fix), and Logstash has the same constraint — neither can bind to traditional syslog port 514 without root. This guide uses `5140`/`5141` for the ELK-side listeners and `5514`/`5515` for the Splunk-side ones instead.

**pfSense can forward to multiple remote syslog servers at once** (up to three) — so one pfSense configuration step feeds both SIEMs simultaneously, rather than needing separate setups.

| Source | → ELK (Logstash) | → Splunk |
|---|---|---|
| Wazuh | `10.10.10.10:5141` | `10.10.10.14:5515` |
| pfSense + Suricata | `10.10.10.10:5140` | `10.10.10.14:5514` |

---

## Part 1 — Wazuh → both SIEMs (native syslog_output)

Run these on the **Wazuh manager VM** (`10.10.10.11`) — now rebuilt on Ubuntu 24.04. No package installation required for this part — this uses Wazuh's own manager binaries only, which follow the same layout regardless of host OS.

**Status: starting fresh here.** The findings below (`wazuh-control` only, no `ossec-control`) were confirmed on the previous OVA build — very likely still true on this rebuild since it's the same Wazuh version installed via the same official method, but worth re-confirming rather than assuming, given how much has already turned out different than expected today.

### 1.1 — Confirm the actual paths and tools on your install

```bash
ls /var/ossec/etc/ossec.conf 2>/dev/null && echo "Found: /var/ossec/etc/ossec.conf"
ls /var/wazuh-manager/etc/ossec.conf 2>/dev/null && echo "Found: /var/wazuh-manager/etc/ossec.conf"
sudo ls -la /var/ossec/bin/ | grep -i control
```

Check the `bin/` directory directly rather than `which wazuh-control` / `which ossec-control` — Wazuh's control scripts aren't on the default `$PATH`, so `which` reports nothing found even when the binary is sitting right there in `/var/ossec/bin/`.

**Confirmed on the previous OVA build:** classic `/var/ossec/etc/ossec.conf` path, and only `wazuh-control` exists — no `ossec-control` at all, not even as a compatibility symlink. Almost certainly still true here — same Wazuh version, same official install method — but run 1.1 above and confirm before proceeding, rather than skip straight to 1.2 assuming it carries over unchanged.

### 1.2 — Add syslog_output blocks to ossec.conf

```bash
sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
sudo nano /var/ossec/etc/ossec.conf
```

Add these two blocks inside the outermost `<ossec_config>` tags (anywhere at that level — order relative to other blocks doesn't matter):

```xml
<syslog_output>
  <server>10.10.10.10</server>
  <port>5141</port>
</syslog_output>
<syslog_output>
  <server>10.10.10.14</server>
  <port>5515</port>
</syslog_output>
```

**Save carefully — this exact step is where a previous attempt silently failed to save.** In nano: `Ctrl+O` (letter O, "Write Out"), then `Enter` to confirm the filename shown at the bottom, then `Ctrl+X` to exit. Don't skip straight to `Ctrl+X` without the `Ctrl+O`/`Enter` sequence first.

**Verify immediately, before doing anything else:**

```bash
sudo grep -A3 syslog_output /var/ossec/etc/ossec.conf
```

This must show your two blocks before you move to 1.3. If it comes back blank, the edit didn't save — redo 1.2 rather than proceeding.

### 1.3 — Restart the manager

**Client-syslog is already enabled by default on current Wazuh versions** — confirmed directly: running `wazuh-control enable client-syslog` on this exact version just prints "This option is deprecated because Client Syslog is now enabled by default." That's not an error, and there's nothing to actually run for enabling it. Just restart so the manager picks up the new `syslog_output` blocks from 1.2:

```bash
sudo systemctl restart wazuh-manager
```

### 1.4 — Verify it started

```bash
sudo tail -20 /var/ossec/logs/ossec.log | grep -i syslog
```

You're looking for two lines like `Forwarding alerts via syslog to: '10.10.10.10:5141'` and `...'10.10.10.14:5515'`. If those don't appear, double check the XML in 1.2 is well-formed — a broken `ossec.conf` can prevent Wazuh services from starting entirely, which is why 1.2 backs up the original file first.

## Part 2 — pfSense + Suricata → both SIEMs (shared setup)

### 2.1 — Enable Suricata alerts to the system log

In pfSense: **Services → Suricata → Interfaces**, click the pencil icon on your Corp-zone interface → **Logging Settings** tab → check **"Send Alerts to System Log"**. Also set **Log Facility: auth** and **Log Priority: notice** — this specific combination is what reliably works; other facility/priority pairs have been reported as inconsistent.

Save, then **restart Suricata on that interface** — it only reads this setting on startup, a running instance won't pick up the change on its own.

### 2.2 — Configure pfSense's remote syslog forwarding

**Status → System Logs → Settings** tab → **Remote Logging Options** section:

- Check **Send log messages to remote syslog server**
- **Source Address:** Default (any)
- **IP Protocol:** IPv4
- **Remote log servers:** add both —
  - `10.10.10.10:5140` (ELK)
  - `10.10.10.14:5514` (Splunk)
- **Remote Syslog Contents:** check **Everything**

Save. This single configuration now sends pfSense's firewall/system logs *and* Suricata's alerts (via 2.1) to both SIEMs at once.

**Note on message length:** pfSense's built-in syslog truncates messages around 480 bytes — fine for the alert summaries this guide targets, not enough for full packet payloads. Not a concern for this build's scope.

## Part 3 — Configure ELK to receive both syslog streams and route by source

Run these on the **ELK VM** (`10.10.10.10`).

### 3.1 — Add two syslog inputs and route by port

```bash
sudo nano /etc/logstash/conf.d/beats-to-es.conf
```

Replace the whole file with:

```text
input {
  beats {
    port => 5044
  }
  syslog {
    port => 5140
    type => "pfsense_suricata"
  }
  syslog {
    port => 5141
    type => "wazuh"
  }
}

filter {
  if [type] == "wazuh" {
    json {
      source => "message"
    }
    mutate { add_field => { "[@metadata][target_index]" => "wazuh-alerts" } }
  } else if [type] == "pfsense_suricata" {
    mutate { add_field => { "[@metadata][target_index]" => "pfsense-suricata" } }
  } else if [log_source] == "openvas" {
    mutate { add_field => { "[@metadata][target_index]" => "openvas-scans" } }
  } else if [agent][type] == "winlogbeat" {
    mutate { add_field => { "[@metadata][target_index]" => "windows-events" } }
  } else {
    mutate { add_field => { "[@metadata][target_index]" => "soc-lab-other" } }
  }
}

output {
  elasticsearch {
    hosts => ["https://10.10.10.10:9200"]
    user => "elastic"
    password => "<your-password>"
    ssl_certificate_verification => false
    index => "%{[@metadata][target_index]}-%{+YYYY.MM.dd}"
  }
}
```
yyy
Routing by `type` (set per-input, at the port level) is deterministic for the syslog sources — no message-content guessing required. The `json` filter on the Wazuh branch parses Wazuh's JSON-formatted alert payload into real fields rather than leaving it as one long string; pfSense/Suricata's plain syslog lines are left as-is. The two new `beats`-based branches (`[log_source] == "openvas"` and `[agent][type] == "winlogbeat"`) are covered in Parts 5 and 6 below — the `beats` input on 5044 that was previously unused now carries both.

```bash
sudo systemctl restart logstash
sudo ss -tunlp | grep -E '5044|5140|5141'   # confirm all three inputs are listening
```

### 3.2 — Verify in Kibana

Browse to `http://10.10.10.10:5601` → `Discover` (or search `Data Views`) → create a data view matching `wazuh-alerts-*` and one matching `pfsense-suricata-*`. Generate some traffic (log into the Windows victim a few times, run a quick Nmap scan from Kali at the Corp zone) and confirm events appear within a minute or two.

---

## Part 4 — Configure Splunk to receive both syslog streams

Run this in **Splunk Web** (`http://10.10.10.14:8000`) on the **Splunk VM**.

**Settings → Data Inputs → UDP → New Local UDP port**, twice:

| Port | Source type | Index |
|---|---|---|
| `5514` | `pfsense_suricata` | `main` (or a dedicated `pfsense` index) |
| `5515` | `wazuh_alerts` | `main` (or a dedicated `wazuh` index) |

Since both pfSense (Part 2) and Wazuh (Part 1) are already configured to send to these exact ports, events should start arriving as soon as each input is active — no further changes needed on the source side.

### Verify

**Search → `index=main sourcetype=wazuh_alerts`** should show Wazuh events; **`index=main sourcetype=pfsense_suricata`** should show pfSense/Suricata events. Same test traffic as the Kibana verification in Part 3.2 works here too.

---

## Part 5 — OpenVAS → ELK

**This is the roughest integration of the five.** Unlike Wazuh and pfSense, OpenVAS has no native syslog or Beats output for scan results. The community tools that exist for this exact purpose have real problems: `gvm-logstash` is explicitly marked "no longer actively maintained... for historical reference only" by its own maintainers, and `VulnWhisperer` (the other commonly recommended option) has multiple recent forum reports of connection failures against current GVM versions. Rather than build on either, this uses **`python-gvm`** — the library Greenbone itself maintains for talking to GVM's own management protocol (GMP) — in a small script, which is more work up front but has no third-party reliability risk baked in. **Expect to iterate on this one more than the others.**

Run these on the **OpenVAS VM** (`10.10.10.12`).

### 5.1 — Install python-gvm and Filebeat

```bash
sudo apt update
sudo apt install -y python3-pip
pip3 install python-gvm --break-system-packages
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list
sudo apt update
sudo apt install filebeat -y
```

### 5.2 — Write the export script

```bash
sudo nano /opt/gvm-export.py
```

```python
#!/usr/bin/env python3
"""Export completed GVM scan results as newline-delimited JSON for Filebeat to ship."""
import json
from datetime import datetime
from gvm.connections import UnixSocketConnection
from gvm.protocols.gmp import Gmp
from gvm.transforms import EtreeCheckCommandTransform

SOCKET_PATH = "/run/gvmd/gvmd.sock"   # confirm this path matches your install — see 5.3
OUTPUT_FILE = "/var/log/gvm-export/results.ndjson"
GVM_USERNAME = "admin"
GVM_PASSWORD = "REPLACE_ME"

connection = UnixSocketConnection(path=SOCKET_PATH)
transform = EtreeCheckCommandTransform()

with Gmp(connection=connection, transform=transform) as gmp:
    gmp.authenticate(GVM_USERNAME, GVM_PASSWORD)
    results = gmp.get_results(filter_string="apply_overrides=0 rows=500 sort-by=created")

    with open(OUTPUT_FILE, "a") as f:
        for result in results.findall("result"):
            record = {
                "@timestamp": datetime.utcnow().isoformat() + "Z",
                "result_id": result.get("id"),
                "name": result.findtext("name"),
                "host": result.findtext("host"),
                "severity": result.findtext("severity"),
                "threat": result.findtext("threat"),
                "description": result.findtext("description"),
            }
            f.write(json.dumps(record) + "\n")
```

### 5.3 — Confirm the GMP socket path and test the script

```bash
sudo find / -name "gvmd.sock" 2>/dev/null
```

Update `SOCKET_PATH` in the script if it differs from the guess above, then:

```bash
sudo mkdir -p /var/log/gvm-export
sudo python3 /opt/gvm-export.py
cat /var/log/gvm-export/results.ndjson
```

You should see one JSON object per line, one per scan finding. If this errors out, the message will usually point at either a wrong socket path or wrong credentials — both are worth checking before assuming something's more deeply broken.

### 5.4 — Schedule it and wire up Filebeat

```bash
sudo crontab -e
```

Add a line to run it every 15 minutes:

```text
*/15 * * * * /usr/bin/python3 /opt/gvm-export.py
```

```bash
sudo nano /etc/filebeat/filebeat.yml
```

```yaml
filebeat.inputs:
  - type: filestream
    id: openvas-results
    enabled: true
    paths:
      - /var/log/gvm-export/results.ndjson
    parsers:
      - ndjson:
          target: ""
          add_error_key: true
    fields:
      log_source: openvas
    fields_under_root: true

output.logstash:
  hosts: ["10.10.10.10:5044"]
```

```bash
sudo systemctl enable filebeat
sudo systemctl restart filebeat
```

### 5.5 — Verify

Run the script manually once more (`sudo python3 /opt/gvm-export.py`) to generate fresh data immediately rather than waiting for the cron schedule, then check Kibana for a `openvas-scans-*` data view with results in it.

---

## Part 6 — Windows → ELK (via Winlogbeat)

This is more standard ground than Part 5 — Winlogbeat is Elastic's own official shipper for exactly this, stable across many versions. This ships **raw Windows Event Logs** directly to ELK, separate from Wazuh's curated alerts — useful for a portfolio to show both curated SIEM alerting *and* raw log-hunting capability side by side. Do this on **both** Windows machines: the victim (`10.10.20.20`) and the AD server (`10.10.20.10`) — the AD server's logs are especially valuable for spotting authentication and lateral-movement activity later in Phase 4.

Run these in an **Administrator PowerShell** on each Windows machine.

### 6.1 — Download and install

Download the Winlogbeat Windows zip from `elastic.co/downloads/beats/winlogbeat` (matching version 9.x, same major version as your ELK stack), then:

```powershell
Expand-Archive .\winlogbeat-9.x.x-windows-x86_64.zip -DestinationPath 'C:\Program Files\'
Rename-Item 'C:\Program Files\winlogbeat-9.x.x-windows-x86_64' 'Winlogbeat'
cd 'C:\Program Files\Winlogbeat'
```

### 6.2 — Configure

Edit `winlogbeat.yml` in that folder:

```yaml
winlogbeat.event_logs:
  - name: Application
    ignore_older: 72h
  - name: Security
  - name: System

output.logstash:
  hosts: ["10.10.10.10:5044"]
```

### 6.3 — Install and start the service

```powershell
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-winlogbeat.ps1
Start-Service winlogbeat
```

### 6.4 — Verify

Check Kibana for a `windows-events-*` data view — Winlogbeat automatically tags every event with `agent.type: winlogbeat` (which is what Part 3's Logstash config routes on) and `winlog.computer_name` (which tells you which of the two Windows machines each event came from, without needing separate indices per host).

---

## Exit criteria for completing Steps 3.6 / 3.7's log source configuration

**ELK:**

- [ ] Wazuh's `ossec.conf` has both `syslog_output` blocks, `client-syslog` enabled, `wazuh-manager` restarted cleanly
- [ ] Wazuh's `ossec.log` confirms it's forwarding to both `10.10.10.10:5141` and `10.10.10.14:5515`
- [ ] Suricata's "Send Alerts to System Log" enabled and interface restarted
- [ ] pfSense remote logging configured with both SIEM targets
- [ ] Logstash listening on 5044, 5140, and 5141
- [ ] Wazuh alerts visible in Kibana under `wazuh-alerts-*`
- [ ] pfSense/Suricata events visible in Kibana under `pfsense-suricata-*`
- [ ] `gvm-export.py` runs cleanly and produces NDJSON output; cron job scheduled
- [ ] OpenVAS scan results visible in Kibana under `openvas-scans-*`
- [ ] Winlogbeat installed and running on both Windows victim and AD server
- [ ] Windows events visible in Kibana under `windows-events-*`, distinguishable by `winlog.computer_name`

**Splunk:**

- [ ] Both Splunk UDP inputs (5514, 5515) created and active
- [ ] Wazuh alerts visible in Splunk under `sourcetype=wazuh_alerts`
- [ ] pfSense/Suricata events visible in Splunk under `sourcetype=pfsense_suricata`
- [ ] *(OpenVAS and Windows → Splunk not yet built — follow-up work, same underlying export script/Winlogbeat install can feed both once ELK side is confirmed working)*

## Troubleshooting

- **`wazuh-control` (or `ossec-control`) or `wazuh-manager` won't restart after editing `ossec.conf`:** almost always malformed XML — a missing closing tag is the most common cause. Restore from the backup (`sudo cp /var/ossec/etc/ossec.conf.bak /var/ossec/etc/ossec.conf`) and re-edit more carefully, or run `sudo /var/ossec/bin/wazuh-control configtest` if your version supports it, before restarting again.
- **No Wazuh events in Kibana/Splunk at all:** check `sudo tail -50 /var/ossec/logs/alerts/alerts.json` on the Wazuh manager first — if that file itself is empty or not updating, the problem is upstream of syslog forwarding entirely (no agents reporting, or no rules triggering). Generate a test alert (a few failed SSH logins against the Windows victim) before troubleshooting the forwarding pipeline.
- **`ossec.log` shows the forwarding lines but nothing arrives at Logstash/Splunk:** confirm the target IP/port actually matches what you configured on the receiving side, and check `sudo ss -tunlp | grep 5141` (or `5515`) on the *receiving* VM to confirm something is actually listening.
- **pfSense/Suricata events missing from one SIEM but present in the other:** double check both entries are actually present under **Remote log servers** in pfSense (2.2) — it's easy to only add one when editing.
- **Suricata alerts still not appearing even after enabling "Send Alerts to System Log":** confirm you restarted Suricata on that specific interface — this setting is read once at startup, not hot-reloaded.
- **Port already in use, or permission denied binding a port:** confirm nothing else on that VM is already bound to the port (`sudo ss -tunlp | grep <port>`), and confirm you're not accidentally trying to use a port below 1024 with a non-root service.
- **`gvm-export.py` fails to connect:** the Unix socket path in `find / -name "gvmd.sock"` (5.3) is the actual source of truth — don't assume the path in the script example matches your install. Also confirm the `admin` credentials in the script match what you set during OpenVAS's first login.
- **`gvm-export.py` runs but produces an empty file:** means GVM has no results matching the filter — confirm at least one scan has actually completed in the Greenbone UI first.
- **Winlogbeat service won't start:** run it in the foreground for diagnostics: `.\winlogbeat.exe -c .\winlogbeat.yml -configtest -e` from the install directory — this prints the actual error instead of just failing silently as a Windows service.
- **Windows events not appearing in Kibana despite Winlogbeat running:** confirm Windows Firewall on that VM isn't blocking outbound traffic to `10.10.10.10:5044` — unlike the Linux VMs in this lab, Windows Firewall is enabled by default and can silently drop this.

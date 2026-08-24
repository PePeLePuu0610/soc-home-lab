# Configure Log Forwarding: Wazuh, pfSense, and Suricata → ELK and Splunk

**Completes:** Step 3.6.3 (ELK log sources) and Step 3.7.3 (Splunk log sources), deliberately done *after* both SIEMs and OpenVAS were already built — this is a return trip per Waterfall discipline: don't move on to SOAR (3.9) until the SIEMs are actually receiving data, since SOAR's entire job is acting on alerts that need to already be flowing in.

This is the most integration-heavy step in the build so far — three log sources, two destinations, six real connections. Every method below was checked against current documentation rather than older tutorials, because this specific integration has a lot of stale advice floating around that breaks on current versions.

## Before you start: the design decisions that shape everything below

**Wazuh forwards via its own native syslog output, not Filebeat.** An earlier version of this guide had Wazuh's manager run a second Filebeat pointed at the external ELK stack — that turned out to be a bad idea for two reasons found while actually running it: the Wazuh manager VM in this lab is deployed from **Wazuh's official OVA appliance** (confirmed built on Amazon Linux 2023, hence `yum` rather than `apt` — different from every other VM in this lab, which is why that difference wasn't visible until hitting it directly), and more importantly, **that appliance already runs its own Filebeat**, shipping alerts to Wazuh's own built-in indexer and dashboard as part of its pre-packaged setup. Editing that file would have broken Wazuh's own UI to fix an unrelated problem. Instead, this guide uses Wazuh's built-in `<syslog_output>` feature in `ossec.conf` — a native manager capability, unrelated to Filebeat, that forwards alerts via syslog to any target you specify. It doesn't touch the existing Filebeat setup at all, and it works the same regardless of which OS or deployment method the manager uses.

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

Run these on the **Wazuh manager VM** (`10.10.10.11`). No package installation required for this part — this uses Wazuh's own manager binaries only, so it doesn't matter whether the underlying OS uses `apt` or `yum`.

**This VM is Wazuh's official OVA appliance** (confirmed Amazon Linux 2023 under the hood, which is why its package manager is `yum`, not `apt` — different from every other VM in this lab, which is why the earlier Filebeat approach broke). Wazuh has also been actively restructuring this exact part of the product recently — recent releases have removed Filebeat as the internal log-shipping component entirely and relocated the manager's install path from `/var/ossec` to `/var/wazuh-manager` on some versions. Rather than assume which side of that change your specific OVA build is on, confirm first:

### 1.1 — Confirm the actual paths and tools on your install

```bash
ls /var/ossec/etc/ossec.conf 2>/dev/null && echo "Found: /var/ossec/etc/ossec.conf"
ls /var/wazuh-manager/etc/ossec.conf 2>/dev/null && echo "Found: /var/wazuh-manager/etc/ossec.conf"
which wazuh-control 2>/dev/null && echo "wazuh-control is available"
which ossec-control 2>/dev/null && echo "ossec-control is available"
```

Use whichever config path actually printed for the rest of this section — the examples below assume the classic `/var/ossec` path and `ossec-control` (still current on most deployed OVA builds as of this writing), but substitute `/var/wazuh-manager` and `wazuh-control` throughout if that's what step 1.1 found instead. The `<syslog_output>` XML syntax itself is identical either way — only the path and the control script name change.

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

### 1.3 — Enable and restart

```bash
sudo /var/ossec/bin/ossec-control enable client-syslog
sudo systemctl restart wazuh-manager
```

If 1.1 found `wazuh-control` instead, use `sudo /var/ossec/bin/wazuh-control enable client-syslog` (or the equivalent path under `/var/wazuh-manager/bin/` if that's what you have) in place of the `ossec-control` line above.

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

Routing by `type` (set per-input, at the port level) is deterministic — no message-content guessing required. The `json` filter on the Wazuh branch parses Wazuh's JSON-formatted alert payload into real fields rather than leaving it as one long string; pfSense/Suricata's plain syslog lines are left as-is.

The `beats` input on 5044 is left in place even though nothing currently uses it, in case you want a Beats-based source later — it's harmless to leave configured.

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

## Exit criteria for completing Steps 3.6 / 3.7's log source configuration

- [ ] Wazuh's `ossec.conf` has both `syslog_output` blocks, `client-syslog` enabled, `wazuh-manager` restarted cleanly
- [ ] Wazuh's `ossec.log` confirms it's forwarding to both `10.10.10.10:5141` and `10.10.10.14:5515`
- [ ] Suricata's "Send Alerts to System Log" enabled and interface restarted
- [ ] pfSense remote logging configured with both SIEM targets
- [ ] Logstash listening on 5044, 5140, and 5141
- [ ] Wazuh alerts visible in Kibana under `wazuh-alerts-*`
- [ ] pfSense/Suricata events visible in Kibana under `pfsense-suricata-*`
- [ ] Both Splunk UDP inputs (5514, 5515) created and active
- [ ] Wazuh alerts visible in Splunk under `sourcetype=wazuh_alerts`
- [ ] pfSense/Suricata events visible in Splunk under `sourcetype=pfsense_suricata`

## Troubleshooting

- **`ossec-control` or `wazuh-manager` won't restart after editing `ossec.conf`:** almost always malformed XML — a missing closing tag is the most common cause. Restore from the backup (`sudo cp /var/ossec/etc/ossec.conf.bak /var/ossec/etc/ossec.conf`) and re-edit more carefully, or run `sudo /var/ossec/bin/wazuh-control configtest` if your version supports it, before restarting again.
- **No Wazuh events in Kibana/Splunk at all:** check `sudo tail -50 /var/ossec/logs/alerts/alerts.json` on the Wazuh manager first — if that file itself is empty or not updating, the problem is upstream of syslog forwarding entirely (no agents reporting, or no rules triggering). Generate a test alert (a few failed SSH logins against the Windows victim) before troubleshooting the forwarding pipeline.
- **`ossec.log` shows the forwarding lines but nothing arrives at Logstash/Splunk:** confirm the target IP/port actually matches what you configured on the receiving side, and check `sudo ss -tunlp | grep 5141` (or `5515`) on the *receiving* VM to confirm something is actually listening.
- **pfSense/Suricata events missing from one SIEM but present in the other:** double check both entries are actually present under **Remote log servers** in pfSense (2.2) — it's easy to only add one when editing.
- **Suricata alerts still not appearing even after enabling "Send Alerts to System Log":** confirm you restarted Suricata on that specific interface — this setting is read once at startup, not hot-reloaded.
- **Port already in use, or permission denied binding a port:** confirm nothing else on that VM is already bound to the port (`sudo ss -tunlp | grep <port>`), and confirm you're not accidentally trying to use a port below 1024 with a non-root service.

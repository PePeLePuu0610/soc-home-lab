# Configure Log Forwarding: Wazuh, pfSense, and Suricata → ELK and Splunk

**Completes:** Step 3.6.3 (ELK log sources) and Step 3.7.3 (Splunk log sources), deliberately done *after* both SIEMs and OpenVAS were already built — this is a return trip per Waterfall discipline: don't move on to SOAR (3.9) until the SIEMs are actually receiving data, since SOAR's entire job is acting on alerts that need to already be flowing in.

This is the most integration-heavy step in the build so far — three log sources, two destinations, six real connections. Every method below was checked against current documentation rather than older tutorials, because this specific integration (Wazuh 4.x → external Elastic Stack) has a lot of stale advice floating around that breaks on current versions.

## Before you start: the design decisions that shape everything below

**Wazuh's old "Filebeat module" approach is fragile and frequently broken on current versions** — multiple people hit exactly this ("Wazuh 4.x has compatibility issues with ELK 9.x... nothing worked") trying to follow older guides. Instead, this guide has Filebeat (for ELK) and a Splunk Universal Forwarder (for Splunk) directly **tail Wazuh's local alerts file** (`/var/ossec/logs/alerts/alerts.json`), which every Wazuh version writes regardless of its internal indexer architecture. This is slightly more manual but far more version-independent.

**Suricata's full EVE JSON output to syslog is unreliable** — several current pfSense forum threads document it simply not working in some package versions. The **"Send Alerts to System Log" checkbox**, however, is confirmed working and is what this guide uses. Trade-off: you get Suricata's alert summaries (source/destination, signature, severity), not full packet payload detail. That's enough for this lab's detection/response goals; if you want full EVE JSON richness later, look into the community [pfELK project](https://github.com/pfelk/pfelk), which adds a `syslog-ng` package specifically for that.

**Non-privileged ports throughout.** Your Splunk service already runs as a dedicated non-root `splunk` user (from the Step 3.7 root-deprecation fix) — binding to the traditional syslog port 514 requires root privileges, which that user deliberately doesn't have. Logstash has the same constraint. So this guide uses `5140` for the ELK-side syslog listener and `5514` for the Splunk-side one, rather than fighting root/capabilities for no real benefit in a lab.

**pfSense can forward to multiple remote syslog servers at once** (up to three) — so one pfSense configuration step feeds both SIEMs simultaneously, rather than needing separate setups.

---

## Part 1 — Wazuh → ELK (via Filebeat)

Run these on the **Wazuh manager VM** (`10.10.10.11`).

### 1.1 — Install Filebeat

```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list
sudo apt update
sudo apt install filebeat -y
```

### 1.2 — Configure Filebeat to tail Wazuh's alerts file and ship to Logstash

```bash
sudo nano /etc/filebeat/filebeat.yml
```

Replace the `filebeat.inputs` and `output` sections with:

```yaml
filebeat.inputs:
  - type: filestream
    id: wazuh-alerts
    enabled: true
    paths:
      - /var/ossec/logs/alerts/alerts.json
    parsers:
      - ndjson:
          target: ""
          add_error_key: true
    fields:
      log_source: wazuh
    fields_under_root: true

output.logstash:
  hosts: ["10.10.10.10:5044"]
```

The `ndjson` parser reads each line as JSON directly into fields (rather than leaving it as one big string), and `fields.log_source: wazuh` tags every event so Logstash can route it to its own index later.

```bash
sudo systemctl enable filebeat
sudo systemctl restart filebeat
sudo systemctl status filebeat
```

## Part 2 — pfSense + Suricata → ELK and Splunk (shared setup)

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

## Part 3 — Configure ELK to receive the syslog stream and route by source

Run these on the **ELK VM** (`10.10.10.10`).

### 3.1 — Add a syslog input and route events by source into separate indices

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
  }
}

filter {
  if [log_source] == "wazuh" {
    mutate { add_field => { "[@metadata][target_index]" => "wazuh-alerts" } }
  } else if "_grokparsefailure" not in [tags] {
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

This keeps Wazuh alerts, and pfSense/Suricata syslog events, in their own indices (`wazuh-alerts-*` and `pfsense-suricata-*`) rather than one undifferentiated bucket — this is what lets you actually filter meaningfully in Kibana later, and matches how a real SOC organizes log sources. Separating Suricata's alerts from plain pfSense firewall logs into a *third* index is possible with a more specific grok pattern on the message content, but isn't necessary for this lab's goals — treat it as an optional refinement if you want the practice.

```bash
sudo systemctl restart logstash
sudo ss -tunlp | grep -E '5044|5140'   # confirm both inputs are listening
```

### 3.2 — Verify in Kibana

Browse to `http://10.10.10.10:5601` → search bar → `Discover` (or search `Data Views`) → create a data view matching `wazuh-alerts-*` and one matching `pfsense-suricata-*`. Generate some traffic (log into the Windows victim a few times, run a quick Nmap scan from Kali at the Corp zone) and confirm events appear within a minute or two.

---

## Part 4 — Wazuh → Splunk (via Universal Forwarder)

Run these on the **Wazuh manager VM** (`10.10.10.11`).

### 4.1 — Download the Splunk Universal Forwarder

Same account-gated pattern as Splunk Enterprise itself: on `splunk.com`, go to **Free Trials & Downloads → Universal Forwarder**, select **Linux .deb**, use **"Download via Command Line (wget)"**, and run the copied command on this VM. Don't hardcode a version — same reasoning as the Splunk Enterprise build.

### 4.2 — Install under a dedicated non-root user

The Universal Forwarder shares Splunk Enterprise's codebase, so it almost certainly has the same root-deprecation behavior you already hit in Step 3.7 — set it up correctly the first time:

```bash
sudo dpkg -i splunkforwarder-*.deb
sudo groupadd splunkfwd
sudo useradd -m -g splunkfwd -d /opt/splunkforwarder -s /bin/bash splunkfwd
sudo chown -R splunkfwd:splunkfwd /opt/splunkforwarder
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk start --accept-license
```

Follow the prompts to create admin credentials for the forwarder (separate from your Splunk Enterprise admin account).

### 4.3 — Point it at Wazuh's alerts file and at your Splunk indexer

```bash
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add monitor /var/ossec/logs/alerts/alerts.json -index main -sourcetype wazuh_alerts
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add forward-server 10.10.10.14:9997
```

That `9997` is the receiving port you already opened on the Splunk VM back in Step 3.7.5 — no changes needed on the Splunk side for this part.

```bash
sudo /opt/splunkforwarder/bin/splunk enable boot-start -user splunkfwd -systemd-managed 1 --accept-license --answer-yes --no-prompt
```

## Part 5 — Configure Splunk to receive the pfSense/Suricata syslog stream

Run this in **Splunk Web** (`http://10.10.10.14:8000`) on the **Splunk VM**.

**Settings → Data Inputs → UDP → New Local UDP port:**

- **Port:** `5514`
- **Source type:** select or create `pfsense_suricata`
- **Index:** `main` (or create a dedicated `pfsense` index if you'd rather keep it separate)

Save. Since pfSense's remote logging config from Part 2 already includes `10.10.10.14:5514`, events should start arriving as soon as this input is active — no changes needed on the pfSense side.

### Verify

**Search → `index=main sourcetype=wazuh_alerts`** should show Wazuh events; **`index=main sourcetype=pfsense_suricata`** should show pfSense/Suricata events. Same test traffic as the Kibana verification in Part 3.2 works here too.

---

## Exit criteria for completing Steps 3.6 / 3.7's log source configuration

- [ ] Filebeat running on Wazuh manager, shipping to Logstash
- [ ] Logstash listening on both 5044 (beats) and 5140 (syslog)
- [ ] Suricata's "Send Alerts to System Log" enabled and interface restarted
- [ ] pfSense remote logging configured with both SIEM targets
- [ ] Wazuh alerts visible in Kibana under `wazuh-alerts-*`
- [ ] pfSense/Suricata events visible in Kibana under `pfsense-suricata-*`
- [ ] Splunk Universal Forwarder running on Wazuh manager under a dedicated non-root user
- [ ] Wazuh alerts visible in Splunk under `sourcetype=wazuh_alerts`
- [ ] pfSense/Suricata events visible in Splunk under `sourcetype=pfsense_suricata`

## Troubleshooting

- **No Wazuh events in Kibana/Splunk at all:** check `sudo tail -50 /var/ossec/logs/alerts/alerts.json` on the Wazuh manager first — if that file itself is empty or not updating, the problem is upstream of Filebeat/the forwarder entirely (no agents reporting, or no rules triggering). Generate a test alert (a few failed SSH logins against the Windows victim) before troubleshooting the shipping pipeline.
- **Filebeat running but nothing arriving in Logstash:** `sudo journalctl -u filebeat -n 100 --no-pager` — look for connection errors to `10.10.10.10:5044`. Common cause: Logstash wasn't restarted after the 3.1 config change.
- **pfSense/Suricata events missing from one SIEM but present in the other:** double check both entries are actually present under **Remote log servers** in pfSense (2.2) — it's easy to only add one when editing.
- **Suricata alerts still not appearing even after enabling "Send Alerts to System Log":** confirm you restarted Suricata on that specific interface — this setting is read once at startup, not hot-reloaded.
- **Splunk Universal Forwarder won't start, same deprecation message as Splunk Enterprise:** you skipped the dedicated-user steps in 4.2 — same root-deprecation behavior as the main Splunk build.
- **Port 5140 or 5514 "already in use" or "permission denied":** confirm nothing else on that VM is already bound to the port (`sudo ss -tunlp | grep 5140`), and confirm you're not accidentally trying to use a port below 1024 with a non-root service.

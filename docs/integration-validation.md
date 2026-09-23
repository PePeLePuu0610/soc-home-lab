# SOC Lab Integration and Validation — Steps 3.6–3.9

> **What this document is:** the as-built validation record for log ingestion, vulnerability scanning, and controlled SOAR response — what was actually configured, what evidence proved it, and what remains open. Where this document and the build guides disagree, **this document is authoritative**: it records the running lab, the guides record the intended procedure. The guides have been reconciled to match.

## Outcome

Verified pfSense firewall logs, Suricata IDS alerts, and Wazuh alerts in both ELK and Splunk. Wazuh validation included events from the Windows victim. Completed an OpenVAS scan of the victim and reviewed the exported report.

Testing used the pod power-on strategy: Pod A remained running, with ELK, Splunk, or OpenVAS powered on as needed.

## Verified environment

| Component | Address | Version |
|---|---|---|
| pfSense with Suricata package | Management: `10.10.10.5`; Corporate: `10.10.20.5`; Attacker: `10.10.30.5` | pfSense CE 2.8.1 |
| ELK | `10.10.10.10` | Elasticsearch, Logstash, Kibana 9.5.2 |
| Wazuh | `10.10.10.11` | 4.14.7; Ubuntu 24.04 LTS; Wazuh Indexer installed |
| OpenVAS | `10.10.10.12` | Report identifies scanner 23.50.20 |
| Splunk | `10.10.10.14` | Reported version 10.2 |
| Windows victim | `10.10.20.20` | Windows 10; Wazuh agent `001` |

Existing `.5` gateway addresses were retained.

## 1. Cleaned up Logstash configuration

Inspection established that `pipelines.yml` loaded `/etc/logstash/conf.d/*.conf` into one `main` pipeline. Configuration filenames did not isolate event processing.

Problems identified:

- `logstash.conf` duplicated the Beats listener on TCP 5044.
- Its unconditional Elasticsearch output lacked explicit HTTPS and credentials.
- `beats-to-es.conf` also had an unconditional output, allowing pfSense events to reach multiple Elasticsearch outputs.
- `10-pfsense.conf` initially lacked Elasticsearch credentials.
- During editing, escaped underscores, a Markdown-formatted URL, and an extra closing brace caused configuration problems.

Cleanup established:

- Removed the redundant configuration from the intended active set.
- Retained UDP 5514 for pfSense.
- Guarded generic filters and output with `if [type] != "pfsense"`.
- Guarded the pfSense output with `if [type] == "pfsense"`.
- Used HTTPS Elasticsearch at `10.10.10.10:9200`.
- Configured daily `pfsense-%{+yyyy.MM.dd}` indices.
- Disabled ILM and data streams for these daily-index outputs.
- Corrected formatting and brace errors.
- Removed temporary `stdout { codec => rubydebug }` after testing.

Created and authenticated `logstash_internal`, assigned the `logstash_writer` role:

- Cluster privileges: `monitor`, `manage_index_templates`.
- Index privileges: `write`, `create`, `create_index`.
- Index patterns: `pfsense-*`, `logstash-*`, `wazuh-alerts-*`, `openvas-scans-*`, `windows-events-*`, and `soc-lab-other-*`.

The documented secret reference was `${PFSENSE_ES_PASSWORD}`. Passwords and keystore contents are excluded from repository documentation.

Validation used:

```bash
sudo -u logstash /usr/share/logstash/bin/logstash --path.settings /etc/logstash -t
sudo systemctl restart logstash
sudo systemctl status logstash --no-pager
sudo ss -lunp 'sport = :5514'
```

Restarts followed successful configuration validation.

## 2. Verified pfSense → ELK

Configured pfSense remote logging to:

- ELK: `10.10.10.10:5514/UDP`
- Splunk: `10.10.10.14:5140/UDP`

Enabled remote categories included System, Firewall, DNS, DHCP, General Authentication, and Captive Portal events.

Validation:

1. Sent a local UDP test to Logstash.
2. Confirmed the marker appeared in Kibana under `pfsense-*`.
3. Generated real firewall traffic and confirmed corresponding pfSense events.
4. Removed debug output, validated the configuration, restarted, and confirmed continued ingestion.

**Result:** pfSense firewall → Logstash → Elasticsearch → Kibana verified.

## 3. Integrated Wazuh → ELK

Confirmed:

- `wazuh-manager` was active.
- `wazuh-csyslogd` was running.
- `<jsonout_output>yes</jsonout_output>` was enabled.
- Existing forwarding destinations were ELK UDP 5141 and Splunk UDP 5515.

Added JSON formatting to the existing ELK forwarding block:

```xml
<syslog_output>
  <server>10.10.10.10</server>
  <port>5141</port>
  <format>json</format>
</syslog_output>
```

Restarted Wazuh successfully and confirmed Logstash listened on UDP 5141.

Kibana evidence included:

- Manager alert: agent `000`, rule `5502`, "PAM: Login session closed."
- Windows alert: agent `001`, `soc-vict-win10`, IP `10.10.20.20`.
- Windows rule `60602`, "Windows application error event," severity 9.
- Structured fields including `agent`, `rule`, and event data.
- No JSON or syslog parsing-failure tags in the reviewed documents.

**Result:** Windows endpoint → Wazuh → ELK verified. Wazuh's existing Indexer configuration was retained.

## 4. Verified Suricata → ELK

Suricata runs inside pfSense. Corporate interface `OPT1CORPVMNET2 (em2)` had:

- Send Alerts to System Log: enabled.
- Facility: `LOCAL1`.
- Priority: `NOTICE`.
- Blocking: disabled during validation.

Service start/stop messages were not accepted as proof of IDS detection. A temporary rule generated a deterministic alert:

```text
alert icmp 10.10.20.20 any -> 10.10.20.5 any (msg:"SOC LAB Suricata forwarding test"; itype:8; sid:1000001; rev:1;)
```

After applying the rule and restarting the Corporate instance, ran on Windows:

```powershell
ping -n 4 10.10.20.5
```

Confirmed the test alert in Kibana, including SID `1000001`, source `10.10.20.20`, and destination `10.10.20.5`.

Suricata messages use the existing UDP 5514 receiver and enter `pfsense-*`; they are not automatically separated into `pfsense-suricata-*`.

**Result:** Suricata detection → pfSense syslog → ELK verified.

## 5. Configured and verified Splunk ingestion

Created two UDP inputs:

| Source | Port | Index | Sourcetype |
|---|---:|---|---|
| pfSense / Suricata | 5140 | `main` | `syslog` |
| Wazuh | 5515 | `main` | `syslog` |

Confirmed both listeners belonged to `splunkd`:

```bash
sudo ss -lunp '( sport = :5140 or sport = :5515 )'
```

### Wazuh troubleshooting and validation

1. A local `logger` test proved Splunk indexing on UDP 5140.
2. A direct test from Wazuh proved network delivery and ingestion on UDP 5515.
3. Packet capture confirmed traffic from `10.10.10.11` to `10.10.10.14:5515`.
4. Wazuh logs showed earlier syslog send errors to Splunk.
5. Restarting Wazuh after Splunk receivers were active restored observed alert forwarding.

Splunk then displayed 21 events, including rules `5501`, `5402`, and Windows endpoint rule `60602`.

The Splunk forwarding block retained its default text format. Structured field extraction remains follow-up work.

### pfSense troubleshooting and validation

1. A direct pfSense `logger` test reached Splunk, proving the network and receiver worked.
2. Inspected generated pfSense syslog configuration and confirmed destination `10.10.10.14:5140`.
3. Re-saved pfSense logging settings through the GUI.
4. A subsequent normal syslog test appeared in both pfSense's local log and Splunk.

This established recovery after reapplying settings; the underlying cause was not conclusively established.

### Actual source verification

Firewall search returned 246 events:

```spl
index=main source="udp:5140" "filterlog"
| table _time host _raw
```

The controlled Suricata test returned 16 matching events:

```spl
index=main source="udp:5140" "SOC LAB Suricata forwarding test"
```

These counts are observations from the validation session, not expected event totals.

**Result:** Wazuh endpoint alerts, pfSense firewall logs, and Suricata detections verified in Splunk.

## 6. Verified OpenVAS scanning and report generation

The initial host export contained asset metadata only. The initial task report showed Done but zero hosts/results, which was insufficient evidence of a meaningful scan.

Diagnostics established:

- OpenVAS routed toward `10.10.20.20` through `10.10.10.5`.
- OpenVAS received no ping replies from Windows.
- Windows could ping OpenVAS.
- The exact filtering point was not established.

Created a dedicated single-host target:

| Setting | Value |
|---|---|
| Hosts | `10.10.20.20` |
| Port list | All IANA assigned TCP |
| Alive Test | Consider Hosts as Alive |

Created and ran the linked task `Windows victim - discovery bypass test`.

Reviewed report `13a42160-b4b9-4c4a-a5ae-39030a1c977d`:

| Evidence | Value |
|---|---|
| Status | Done |
| Hosts scanned | 1 — `10.10.20.20` |
| Scan start | September 20, 2026, 17:01:23 UTC |
| Scan end | September 20, 2026, 18:53:52 UTC |
| Duration | 1 hour, 52 minutes, 29 seconds |
| Open port | 7680/TCP |
| Results | 4 informational results |
| Reported vulnerabilities | 0 |
| Reported scanner errors | 0 |
| OS identification | Unsuccessful |
| Feed version | `202608211559` |

Informational results covered traceroute, OS detection, an unidentified service, and hostname determination. The service name `pando-pub` was explicitly a guess.

**Result:** Step 3.8's basic scan/report requirement met. This limited network scan does not establish that Windows has no vulnerabilities or provide a comprehensive authenticated assessment.

## 7. Verified Shuffle deployment, filtering, response, and reversal

On September 21–22, 2026, deployed Shuffle at `10.10.10.13`, verified execution after reboot, integrated Wazuh JSON webhooks, and tested both outcomes of the marker condition. A dedicated API account scoped to agent `001` enabled automatic marker creation on Windows. A separate manually started workflow removed it; endpoint checks confirmed both effects.

The full configuration, evidence IDs, troubleshooting, and limitations are recorded in [Shuffle Deployment and Response Validation](build-shuffle.md). This path is directly Wazuh → Shuffle → Wazuh API → Windows; the SIEMs are parallel consumers.

## Completion status

| Milestone | Status |
|---|---|
| Step 3.6 — ELK receives all three required sources | Verified |
| Step 3.7 — Splunk receives all three required sources | Verified |
| Step 3.8 — Windows victim scan and report | Verified with coverage limitations |
| Step 3.9 — Shuffle | Verified: automatic marker response and separate manual reversal |

An operator-created snapshot and backup were confirmed earlier in the integration work. A post-completion backup has not yet been recorded.

## Remaining actions

### Security and correctness debt

- Replace Elasticsearch certificate-verification bypass with trusted CA verification.
- Confirm removal of temporary Suricata SID `1000001`; apply and restart the affected instance.
- Define Elasticsearch retention.

### Open technical follow-ups

- Investigate the observed one-hour pfSense/Splunk timestamp discrepancy. Most likely timezone handling rather than clock drift: pfSense syslog emits local time with no UTC offset and Splunk applies its own assumption. Compare pfSense **System → General → Timezone** against the Splunk host's, then either set pfSense to UTC or pin `TZ` in a Splunk `props.conf` stanza for that sourcetype.
- Configure structured Splunk field extraction.
- Verify OpenVAS feed synchronization and plan an authenticated Windows scan.
- Document receiver startup and forwarding checks for pod switching; historical UDP delivery while a receiver is off was not validated.

### Housekeeping

- Retain screenshots and the OpenVAS XML as validation evidence.
- Record a new snapshot/backup of the completed baseline.
- Archive sanitized Shuffle workflow exports and capture installed image digests / upstream commit for reproducibility.
- Complete the remaining Phase 3 checklist and plan Phase 4 attack tests.
- Replace Wazuh API TLS verification bypass and review Shuffle HTTP access / published ports before wider exposure.

Controlled ping alerts proved IDS detection and forwarding. The later marker test proved automated response plumbing and manual reversal. Neither proves completion of the Phase 4 attack-simulation criteria.

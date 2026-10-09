# Post-reboot readiness and telemetry validation

## Evidence and status

Joey reports all VMs were powered off before snapshots. The snapshot label is
`Pre-victim authenticated scan — SMB rule and RemoteRegistry enabled 10/6/26`.
The label date differs from this session's 2026-10-08 date; actual snapshot creation time is not verified. Snapshots are rollback points, not independent backups.

Reported startup order: pfSense, DC, victim, OpenVAS, Wazuh, ELK.
Console and security web GUI access were reported successful. Splunk remains powered off.

Screenshots confirm:

| Check | Observed result |
|---|---|
| Victim `soc-vict-win10` RemoteRegistry | Running / Manual |
| DC `soc-adsrv-win19` RemoteRegistry | Running / Automatic |
| OpenVAS to victim TCP 445 | `nc -vz -w 3 10.10.20.20 445` succeeded |
| Direct SMB authentication | `SOCHOMELAB\secadmin` listed victim `ADMIN$` using smbclient |
| pfSense syslogd | Running; remote delivery still needs fresh-event validation |
| Wazuh agent 001 | Active, victim 10.10.20.20 |
| Wazuh agent 002 | Active, DC 10.10.20.10 |

Active agents establish connectivity, not fresh alert forwarding. Direct SMB authentication does not establish Greenbone saved-credential authentication or registry/WMI coverage. Subsequent screenshots confirm Domain Credentials is assigned to the victim-only target.

## ELK checks pending execution

Subsequent `console_export.txt` from Kibana Dev Tools confirms populated `wazuh-alerts-*` and `pfsense-*` indices exist. The data-view selector did not show a Wazuh view. This establishes indexed data, not current post-reboot delivery. Wazuh indices include 2026.10.08 (26,478 documents) and 2026.10.09 (5,932 documents); pfSense indices include 2026.10.08 (1,094,337 documents) and 2026.10.09 (256,023 documents). Index date suffixes alone do not establish event time or clock correctness. Create a Kibana data view matching `wazuh-alerts-*`, using `@timestamp` if available, then execute the fresh-event checks below. Snapshot label date 10/6/26 was confirmed by Joey to be a typo; actual snapshot timestamp remains unverified.

Use Kibana Discover, KQL mode, Last 15 minutes, and refresh every 10 seconds during validation. Sort newest first. This interval and a two-minute arrival goal are proposed lab acceptance criteria, not measured outcomes.

The existing [ingestion plan](elk-ingestion-plan.md) documents Windows alerts via Wazuh in `wazuh-alerts-*`. Direct Winlogbeat ingestion remains unverified. Use Wazuh fields for this path rather than assuming ECS host fields.

Select `wazuh-alerts-*` and query:

```kql
agent.id: "001" OR agent.id: "002"
```

Review each agent separately and add `@timestamp`, `agent.id`, `agent.name`, `rule.id`, `rule.description`, and `data.win.system.eventID` where available.

```kql
agent.id: "001" AND data.win.system.channel: "Microsoft-Windows-Windows Defender/Operational"
```

For DC, substitute agent `002`. Defender alerts are event driven; an empty short window does not prove forwarding failure.

In `pfsense-*`, start with `*`, inspect the latest document, then use `message: "filterlog"` only if the raw syslog text is indexed in `message`. Compare a newly generated, locally logged firewall event with its ELK counterpart by time, source/destination, and port. Running syslogd alone does not validate this path.

Pass each source only after a known fresh event reaches ELK with the correct identity, sensible event time, and no parsing-failure tags. Widen the time range and inspect timestamps before concluding no ingestion.

## Next scan gate

## ELK endpoint export validation result

Joey created the Wazuh Alerts data view and exported the Last 15 minutes query for agents 001 or 002. `ELK Stack Refresh Results.csv` contains 348 rows: victim 001 has 277 and DC 002 has 71. All rows have structured agent, rule, event ID, and channel columns. Displayed timestamps range from Oct 8, 2026 22:44:40 to 22:59:11; the CSV omits timezone offsets, so these are retained as displayed rather than converted to UTC or Mountain time.

Channels: Security 342, System 5, Defender Operational 1. Event IDs: 4634 (132), 4624 (113), 4672 (88), 4688 (7), 36874 (5), 4769 (2), 1150 (1). The Defender event is from DC agent 002 at displayed 22:48:34, rule 62128, reporting the antimalware platform running in a healthy state. There are no 1116 or 1117 events in this export.

**Result:** post-reboot endpoint alerts visible in separate ELK for both Windows hosts, with structured selected fields. Export plus operator's recent-window screenshot supports current ingestion. Exact forwarding latency, timezone correctness, parsing-failure tags (not exported), victim Defender collection, and fresh pfSense delivery are not validated by this file. Authentication failures or attack attribution cannot be inferred from these event counts alone.

Evidence SHA256: `42272A3617AC536D0D29145DF99100BCA9EEB712E19E234F717E4D75EC6A7DB4`. Raw CSV remains in the private Downloads folder and is not added to Git.

## Victim scan in progress

## pfSense export: fresh delivery still open

The later `Untitled Discover session (4).csv` export contains 10,000 selected records from the `pfsense` data view, whereas the screenshot shows 549,966 matching documents. This is a subset, not the complete 24-hour result set. The newest exported record is displayed Oct 8 at 22:13:49.038, a pfSense GUI login from 10.10.40.1, with host.ip 10.10.10.5. Its raw syslog message time is 22:13:48. The screenshot search ends at 23:18:25.062, leaving approximately 65 minutes between the newest visible record and the search endpoint.

The subset contains repeated `syslogd: sendto: Host is down` messages. These do not identify which remote destination failed; Splunk was intentionally powered off, so an ELK failure cannot be inferred from this message alone. Historical firewall and system logs exist in ELK, but current continuous pfSense forwarding and the specific OpenVAS SMB connections remain unverified. Next diagnostic: create a unique local pfSense system-log marker, verify it locally, and search the same marker in Kibana without changing services. If absent, inspect configured remote destinations/categories and the ELK UDP 5514 receiver.

### Subsequent recovery: system-log forwarding passed

Joey observed syslogd stopped on pfSense and restarted it. The stop time and cause are unknown. After rerunning logger with `PEPESLAB-ELK-REFRESH-02`, screenshot evidence shows one matching document in Kibana, host.ip 10.10.10.5, displayed @timestamp Oct 8, 2026 23:27:37.227. The raw message reads `<13>Oct 8 23:27:36 SOC-VALIDATION[69101]: PEPESLAB-ELK-REFRESH-02`. These displayed timestamps lack an explicit timezone. Their approximate one-second difference is not an independently measured end-to-end forwarding latency.

**Validated:** a fresh pfSense system-log marker reached separate ELK after the operator restarted syslogd. **Still open:** fresh firewall-category event delivery, syslogd remaining active, and root cause of the service stop. Capture a newly logged OpenVAS-to-victim TCP 445 connection and match its source port, rule tracker 1791410049, addresses, and timestamps in ELK. Recheck syslogd after this test; do not infer stability from a single delivered marker.

### Subsequent firewall delivery passed

### syslogd process and destination investigation

Operator console at Oct 8 23:42:12 MDT shows main syslogd PID 25667 with `-f /etc/syslog.conf`, plus helper processes. Joey clarified the earlier service-stop observation was a red X in pfSense Services followed by using the start button; subsequent green status and processes confirm current operation, not the earlier stop cause.

`/etc/syslog.conf` is a generated include wrapper for `/var/etc/syslog.d`. The initial search of that wrapper returned no destinations. The suggested `/etc/syslog.log.conf` path was an assistant misreading and does not exist; it is not a valid troubleshooting step. Read-only `grep -Rn '@' /var/etc/syslog.d` shows forwarding directives in `/var/etc/syslog.d/pfSense.conf` for ELK `10.10.10.10:5514` and Splunk `10.10.10.14:5140`. Splunk is intentionally powered off. Sending to that unavailable receiver is a plausible explanation for send errors, but the error text does not identify the receiver and does not prove the daemon's earlier stop cause. No forwarding changes have been executed. Recommended pod-aware configuration: when Splunk is paused, retain only ELK as the GUI-configured remote receiver; restore the Splunk destination when its pod resumes. Record and preserve both addresses before changing settings; do not edit generated configuration files.

Later screenshot of the `message: "filterlog"` search shows fresh records through displayed Oct 8 23:34:22.685. At 23:34:16.678, raw filterlog shows tracker 1791410049, interface em1, pass/in, TCP SYN, source 10.10.10.12:35034 to victim 10.10.20.20:135. host.ip is 10.10.10.5. This validates current pfSense firewall-category delivery to ELK and permitted scanner-to-victim traffic; the displayed event is TCP 135, not the separate TCP 445 nc test. RPC authentication and dynamic-port reachability are not established by a passed SYN.

The earlier `message: "10.10.10.12"` screenshot returned 458 documents with newest displayed result at 19:06:01.212, showing historical Suricata records. The filterlog search later returned 274,637 documents with fresh firewall entries. Do not infer a field-mapping defect from these separate screenshots taken at different times. Current forwarding is restored; service stability and stop root cause remain open. Preserve the successful simple filterlog query as the baseline validation search.

Joey reports the new scan is running. The task screenshot shows 0% and one report; no scan outcome or authenticated coverage is established yet.

| Setting | Recorded value |
|---|---|
| Credential name | Domain Credentials (renamed by Joey) |
| Credential login | sochomelab\secadmin |
| Target | Victim authenticated validation |
| Host count / address | 1 / 10.10.20.20 |
| Alive test | Consider Alive (operator reported) |
| Port list | All IANA assigned TCP and UDP (screenshot confirmed) |
| SMB (NTLM) credential | Domain Credentials (target screenshot confirmed) |
| Task | Victim authentication validation |
| Scanner | OpenVAS Default |
| Scan configuration | Full and fast |
| Maximum concurrent NVTs per host | 4 |
| Task minimum QoD | 0 |
| Add results to Assets / Apply Overrides | Yes / Yes |
| Report retention | Do not automatically delete reports |

The pictured port list includes UDP; an earlier corporate-target screenshot showed All IANA assigned TCP only. This is a recorded difference, not proof that the current corporate target differs. Scan duration is not directly comparable without checking actual port coverage and errors.

Keep Defender enabled. The completed report must independently establish SMB login and registry/WMI authenticated coverage. Export CSV and XML with the report filter explicitly set to minimum QoD 0 and all severities including Log; the task's minimum QoD setting is separate from report filtering. Review any applied overrides before interpreting severity. Record start/end timestamps, host count, scan errors, and coverage limitations. Repository reconciliation and public publication remain outstanding separate tasks.

## Applied change: pause pfSense forwarding to Splunk

Joey reports the remote logging change was saved and applied. Screenshot confirms only `10.10.10.10:5514` remains in Remote log servers; the other two fields are empty. Selected contents remain System, Firewall, DNS, DHCP, General Authentication, and Captive Portal events. This removes the configured Splunk receiver while that VM is intentionally powered off.

Rollback: when Splunk is powered on and its UDP 5140 receiver is ready, restore `10.10.10.14:5140` in the second Remote log servers field through the GUI, save/apply, and validate delivery to both destinations. Do not restore solely to reproduce the prior configuration while Splunk remains off.

Post-change validation pending: confirm syslogd running, send unique marker `PEPESLAB-ELK-REFRESH-03` and find it in ELK, and check newly generated system-log entries for continued send errors. A successful marker proves current system-log delivery; daemon stability and stop root cause require separate evidence. No claim that this change fixes the earlier service stop is made.

Subsequent screenshot confirms **post-change marker delivery passed**: one document for `PEPESLAB-ELK-REFRESH-03`, host.ip `10.10.10.5`, displayed @timestamp Oct 8, 2026 23:53:09.544, raw syslog time Oct 8 23:53:09, tag `SOC-VALIDATION[22423]`. ELK forwarding remains functional after removing the paused Splunk destination. Absence of new send errors, sustained daemon health, and cause of the earlier stop are not established by this screenshot. No additional restart is required on the evidence provided.

## References

- [Elastic KQL syntax](https://www.elastic.co/docs/reference/query-languages/kql)
- [Elastic Discover](https://www.elastic.co/docs/explore-analyze/discover/discover-get-started)

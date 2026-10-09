# Recovery runbook — reference v1.0

Owner: Joey. Reviewed October 8, 2026. Document complete for reference; operational validation and identified risks remain open.

Legend: OBSERVED: supplied evidence; REPORTED: operator account; RECOMMENDED: future procedure; SAMPLE: illustrative, not executed.

## Incident record

| Field | Your entry |
| --- | --- |
| Failure date/time and timezone | OBSERVED: October 8, 2026. Exact failure time/timezone not recorded. |
| What happened / symptoms | Host system Stopped responding, then rebooted spontaneously |
| Systems affected | HOST: PePeslab<br>VMz: soc-fw-pfsense, soc-xdr-wazuh, soc-siem-elk, soc-victim-win10, soc-adsrv-win19 & soc-vuln-openvas |
| Recovery start and finish | REPORTED: 10/08/2026 09:39:15 AM; whether this is start or finish and its timezone are unconfirmed. Availability recovery estimated at 30 minutes. |
| Impact / data loss | OBSERVED: feed synchronization interrupted. Data loss not assessed; do not infer none. |
| Recovery objective | Restore essential lab services and verify control operation. |
| Evidence location | KNOWN: supplied screenshots and Downloads/openvas-validation-status.txt; DC Defender EventID 1116.txt/1117.txt and Wazuh screenshots. RECOMMENDED: keep an evidence manifest linking original private files. SAMPLE location (not created): <private-evidence-root>/2026-10-08-recovery. |

## Actual startup order

| Order | VM / service | Action you performed | Dependency / wait condition | Result and evidence |
| --- | --- | --- | --- | --- |
| 1 | Soc-fw-pfsense | Started VM via Workstation MGR | RECOMMENDED: host storage and VMware networking ready; verify firewall interfaces and routing. | Logged on to interface with out error. Manually start syslog daemon |
| 2 | Soc-adsrv-win19 | Started VM via Workstation MGR | OBSERVED: no explicit readiness wait documented. RECOMMENDED: verify VM boot, required network/DNS paths and service readiness before dependent checks. | Logged on to interface with out error. |
| 3 | Soc-victim-win10 | Started VM via Workstation MGR | OBSERVED: no explicit readiness wait documented. RECOMMENDED: verify VM boot, required network/DNS paths and service readiness before dependent checks. | Logged on to interface with out error. |
| 4 | Soc-xdr-wazuh | Started VM via Workstation MGR | OBSERVED: no explicit readiness wait documented. RECOMMENDED: verify VM boot, required network/DNS paths and service readiness before dependent checks. | Logged on to interface with out error. |
| 5 | Soc-SIEM-ELK | Started VM via Workstation MGR | OBSERVED: no explicit readiness wait documented. RECOMMENDED: verify VM boot, required network/DNS paths and service readiness before dependent checks. | Logged on to interface with out error. |
| 6 | Soc-vuln-openvas | Started VM via Workstation MGR | OBSERVED: no explicit readiness wait documented. RECOMMENDED: verify VM boot, required network/DNS paths and service readiness before dependent checks. | Logged on to interface with out error |
| 7 | Intentionally paused services | REPORTED: not started | RECOMMENDED: retain intentionally paused state. | Not part of essential recovery acceptance. |
| 8 | Future additions — SAMPLE | SAMPLE: record another VM here if scope expands. | SAMPLE: list actual dependencies. | SAMPLE only; no additional VM recovery claimed. |

## Availability and functional checks

| System | Check performed | Expected result | Actual result / status | Evidence / time |
| --- | --- | --- | --- | --- |
| pfSense | REPORTED: GUI login, services check, external ping; manual syslog start. | GUI and connectivity available; policy enforcement checked separately. | Availability reported passed; segmentation not tested after reboot. | Operator observation; specific log references pending. |
| DC / DNS | OBSERVED: local login; WMI, SMB, RemoteRegistry and WazuhSvc running. | Domain login and services work; explicit DNS query succeeds. | Login/service checks passed; DNS functional check not documented. | DC service screenshots; DNS evidence pending. |
| Windows victim | REPORTED: local login. | Login works; agent 001 sends recent events. | Login passed; recent agent 001 evidence not supplied in this review. | Operator observation; agent status/event capture pending. |
| Wazuh | OBSERVED: dashboard displays DC agent 002 Defender alerts. | Manager processes and indexes events from both endpoints. | DC Defender path passed; both-agent acceptance still needs evidence. | docs/defender-telemetry-validation-2026-10-08.md; rules 62123/62124. |
| ELK | REPORTED: web GUI login. | GUI available; new expected logs searchable. | GUI passed; post-reboot ingestion not documented. | Operator observation; recent log query evidence pending. |
| OpenVAS | OBSERVED: current feeds, cleared sync banner, running service containers and scan. | Services ready; approved task executes; final report assessed. | Readiness passed; scan reported 83% during review; final assessment pending. | openvas-validation-status.txt; feed/task screenshots. Empty log export provides no diagnostic proof. |
| Other VMs / services | REPORTED: intentionally paused. | Paused services remain outside essential recovery scope. | Not applicable to essential recovery. | Record exact paused VM names on next inventory review. |

## Backup inventory

| Backup | Location / filename | Backup date | Protection / access | Restore tested? / evidence |
| --- | --- | --- | --- | --- |
| pfSense configuration XML | Private backup directory (location retained in private OneNote) | 10/07/2026 | REPORTED access: Joey. Encryption/ACL/off-host copy not verified; XML contains sensitive data. | No |
| Wazuh agent configuration backup | PREVIOUSLY OBSERVED: C:\Program Files (x86)\ossec-agent\ossec.conf.before-defender.bak on DC; current existence unverified. | Historical rollback during Defender setup; exact backup time unknown. | RECOMMENDED: restrict access and preserve a protected copy. | Historical configuration rollback succeeded; current restore readiness not tested. |
| VM snapshots / independent backup | REPORTED: powered-off snapshots dated 10/06/2026. Independent VM backup copy not documented. | 10/06/2026 (reported) | File-system access reported; off-host protection unverified. | Not tested. Snapshots are rollback points; independent backup validation remains open. |

## Manual interventions

| System / step | Command or action used | Why needed | Result | Required after every restart? |
| --- | --- | --- | --- | --- |
| DC RemoteRegistry | Start-Service -Name RemoteRegistry | Observed stopped during post-reboot scan preparation. | Joey supplied screenshot showing Running. | Unknown |
| Other intervention | Start syslog deamon on pfsense | Wasn't started. Root cause unknown | REPORTED: service manually started; logging recovery not independently verified. | Observed once in this recovery; recurrence unconfirmed. |
| Future intervention — SAMPLE | SAMPLE: record exact command/service action. | SAMPLE: symptom and supporting evidence. | SAMPLE: observed result and timestamp. | Unknown until tested; no intervention claimed. |

## Open risks

| Problem / risk | Observed evidence | Resolution or proposed action | Owner | Status |
| --- | --- | --- | --- | --- |
| pfSense syslog startup | Joey reports stopped service and manual start. | RECOMMENDED: identify exact service, inspect startup/log errors and verify a new firewall log reaches its destination. | Joey / Niko | Open; no service change during active scan. |
| Backup resilience / restore confidence | XML exists per report; snapshots reported; independent VM copy not documented. | RECOMMENDED: inventory protected copies, verify Wazuh configuration backup, plan isolated restore validation. | Joey / Niko | Open; restore test requires separately planned scope. |
| Post-reboot functional validation | Segmentation not tested; DNS, ELK ingestion and victim agent evidence incomplete. | RECOMMENDED: run bounded read-only checks and retain results after scan. | Joey / Niko | Open. |
| Host failure cause | Host froze and rebooted spontaneously; root cause unknown. | RECOMMENDED: inspect host reliability/system events before attributing to memory or hardware. | Joey / Niko | Open; investigation pending. |

## Acceptance and timing

| Criterion / metric | Result | Evidence / remaining work |
| --- | --- | --- |
| Essential VMs and services available | REPORTED pass for GUI/local availability. | Operator observations; not full functional acceptance. |
| Both Wazuh corporate agents active and reporting | DC verified; victim verification pending. | DC Defender evidence confirmed; capture active status and recent events for agent 001. |
| DC Defender events visible in Wazuh | Verified for observed October 8 event pairs. | Events 1116/1117 matched rules 62123/62124; see Git validation record. |
| OpenVAS feed readiness and completed scan review | Scan review pending. | Current feeds and scan startup verified; latest user progress 83%. Final XML/CSV review pending. |
| Selected allowed/blocked traffic tests after reboot | Not tested | Testing procedures to be created by Niko |
| Backup restore validation | Not tested | Open risk; plan an isolated restore exercise separately. |
| Time to restore essential availability | Approximately 30 minutes — OPERATOR ESTIMATE. | No measured start/end interval established. |
| Time to complete functional validation | Pending | Scan review and functional tests remain open; do not claim a completed duration. |

## Next actions

Next three actions: (1) Joey: export final OpenVAS XML/CSV once Done; Niko: assess both-target authentication, errors and findings. (2) Joey/Niko: capture agent 001 reporting, DNS and ELK ingestion evidence, then execute selected segmentation checks. (3) Joey/Niko: verify backup inventory and syslog startup behavior; completion requires source-linked results and a separately planned restore test.

## Evidence convention

Recommended naming: YYYY-MM-DD_HHMMSS_timezone_system_check.ext. SAMPLE filename: 2026-10-08_180000_MDT_wazuh_agent-status.png (illustrative only). Maintain capture time, source system, check, expected result, observed result, and original private file location. Existing source references are filenames, not newly collected or copied evidence.

## Suggested future startup checks

Recommended, not executed as a drill: host storage and VMware networks ready; pfSense interfaces/routing ready; DC domain/DNS services ready; monitoring platforms ready; endpoint agents connected; scanner feeds and services ready. Start monitoring before planned test traffic where practical. Preserve actual startup order separately from this recommendation. If a check fails, capture the error and investigate; do not blindly restore or reset configuration.

Snapshot guidance: https://blogs.vmware.com/cloudprovider/2021/10/disaster-recovery-journal-or-delta.html


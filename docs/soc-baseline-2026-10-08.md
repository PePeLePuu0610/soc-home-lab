# SOC baseline — 2026-10-08

Working summary maintained privately in OneNote; Git is the authoritative project record.

## Executive summary

Retrospective baseline recorded October 8, 2026; owner Joey. The lab has demonstrated selected network controls, endpoint reporting, and a completed two-host vulnerability scan. Operational maturity remains in validation. This record summarizes supplied screenshots, exports, and prior investigation notes; it is not a fresh test of the live environment.

## 1. Network architecture and pfSense segmentation

Implemented: management 10.10.10.0/24, corporate 10.10.20.0/24, and attacker 10.10.30.0/24 networks behind pfSense CE 2.8.1; WAN 10.10.40.5 uses VMware NAT gateway 10.10.40.2. Corporate targets are DC 10.10.20.10 and Windows victim 10.10.20.20. Management services include ELK .10, Wazuh .11, OpenVAS .12, and Shuffle .13. Splunk .14 is intentionally paused. Evidence: prior topology, interface, route, and firewall validation records. Limitations: same-subnet traffic is outside routed firewall enforcement; anti-lockout remains enabled; a full IPv6 control review and post-reboot regression test remain open.

## 2. Alias cleanup and allowed/blocked traffic

Verified for tested paths: oversized aliases corrected, broad rules disabled, approved OpenVAS source 10.10.10.12 scoped to the two corporate targets, and administrative access scoped to the approved host and ports. RDP administration and Wazuh forwarding passed. Corporate access to management services outside approved exceptions was blocked. Kali probes against corporate, management, and host targets were filtered with matching firewall block records. Evidence: pfSense rule screenshots and exported traffic records, including openvas-dc-filterlog.txt. Limitation: these checks cover selected paths, not every possible protocol. Next: repeat the test matrix after recovery and preserve timestamped results.

## 3. Wazuh endpoint reporting and Defender collection

Verified before recovery: corporate agents 001 (victim) and 002 (DC) reported. Implemented on DC: eventchannel collection for Microsoft-Windows-Windows Defender/Operational. A malformed edit caused WazuhSvc to stop; restoring the known-good configuration recovered it. Corrected configuration remained running, and ossec.log confirmed the Defender channel was opened at 23:43:42 on October 7. The last shown Defender detection/remediation occurred about 23:17, before collection was enabled. Evidence: service status, configuration troubleshooting screenshots, agent log, EventID 1116.txt and EventID 1117.txt. Open: a new event must be confirmed locally and in Wazuh; channel initialization alone does not prove ingestion or alerting.

## 4. OpenVAS scan and coverage limits

Scanner logs reported the two-host task Done at 05:39:52 UTC on October 8 (23:39:52 MDT on October 7). Partial report exports demonstrate DC SMB authentication and registry access; equivalent authenticated coverage for the victim remains unproven. Two visible medium findings on the victim concerned RPC enumeration and deprecated TLS 1.0/1.1 on RDP. DC checks timed out, and Defender detected and successfully remediated VirTool:Win32/Impacket.D command activity during the scan period. This is consistent with possible scan interference, but does not establish that every timeout was caused by Defender or prove the command's originating host. Evidence: report-acb014f3-f1c5-44a2-b8ce-8536a7eaa315.xml/.csv and DC events. Open: verify exports reflect the final completed report; repeat the approved scan with Defender enabled and review authentication, errors, coverage, and findings.

## 5. Feed update and readiness

Verified in latest supplied Feed Status screenshot: NVT 20261007T0608, SCAP 20261008T0215, CERT 20261008T0428, and GVMD_DATA 20261008T0515 all showed Current. The same screenshot still displayed Feed is currently syncing and scans unavailable. Evidence: feed status screenshot and openvas-feed-start.txt/openvas-after-reboot.txt. Open: confirm the syncing banner clears and scanner/task readiness before launching another scan. Current feed versions alone do not establish completed import readiness. Historical container exit code 137 does not by itself prove out-of-memory failure.

## 6. Backup and recovery

Completed per Joey: local pfSense XML backup, including extra data and SSH keys, followed by recovery of VMs and web interfaces after the host PC failed and required reboot. The backup was unencrypted and must remain private. Evidence: backup settings screenshot, recovery report from Joey, and post-reboot container status export. Limitations: no restore drill or full end-to-end recovery acceptance test has been recorded. Next: document startup order, backup location and protection, recovery checks, and a bounded restore-validation plan.

## Control alignment

NIST CSF mapping for this baseline: Govern—authority, evidence handling, and risk decisions; Identify—assets and topology; Protect—segmentation and approved access; Detect—Wazuh and Defender telemetry; Respond—Defender remediation and investigation; Recover—backup and startup validation. These are activity mappings, not compliance certification. ATT&CK hypotheses for validation: T1046 Network Service Discovery (authorized scanning), T1021.002 SMB/Windows Admin Shares, and T1047 Windows Management Instrumentation (remote-check investigation). Exact command-to-technique attribution remains provisional where execution evidence is incomplete; authorized scanner activity must be distinguished from malicious behavior.

## Risks and optimizations

Primary risks: overstating scan coverage, assuming telemetry delivery from a running service, incomplete post-reboot validation, and exposing sensitive evidence in a public portfolio. Improve through a repeatable test matrix, source-linked findings, configuration validation before service restart, protected backups, and explicit acceptance criteria. Preserve Defender protections while investigating scanner compatibility.

## Tasks, deliverables, and success metrics

Owner Joey, assisted by Niko. Sequence: (1) confirm feed import readiness; (2) verify DC RemoteRegistry and both Wazuh agents after recovery; (3) run the approved two-host scan and export the final XML/CSV; (4) validate a new Defender event through collection, delivery, and relevant Wazuh alert/search behavior; (5) repeat selected allowed/blocked network tests; (6) complete recovery runbook and evidence review. Deliverables: final scan assessment, telemetry validation record, segmentation test matrix, recovery runbook, and reviewed portfolio case study. Success criteria: both targets' authentication status documented; all scan errors triaged; a new Defender event traced end to end; selected network tests match policy; recovery checks pass with evidence. Targets are acceptance criteria, not claims of completion.

## Record ownership and next actions

Git remains authoritative. This OneNote page is a working summary; promote validated findings and decisions into the repository. Keep raw backups, credentials, and private evidence out of public Git. The immediate next action is feed-readiness confirmation, followed by the post-recovery checks. Learning continues in parallel using the Learning and Career notebook and completed learning register. No new spending or external communications are authorized by this baseline.


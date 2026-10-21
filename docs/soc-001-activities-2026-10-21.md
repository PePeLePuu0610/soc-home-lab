# SOC-001 activities — October 21, 2026

Detailed commands, purpose, observed results, failed attempts and screenshot locators: [October 21 command and evidence log](soc-001-command-evidence-2026-10-21.md). This page summarizes outcomes; the companion log provides the operational audit trail.

## Accepted decision

Joey approved keeping `SOC-OpenVAS-WMI-In` enabled as the victim's persistent scan-ready baseline. Source 10.10.10.12 only; Domain profile only; inbound TCP scoped to svchost.exe / Winmgmt. No routine rule toggle is required after reboot. Verify effective policy, DomainAuthenticated profile, and service readiness before each scan. RemoteRegistry remains Manual and must be started if stopped. Defender remains enabled.

Implementation, exact command, verification and reversible disable procedure are maintained in the [Windows endpoint build guide](build-windows-endpoint-scan-readiness.md#october-21-accepted-wmi-baseline).

## Completed evidence

- PMO-000 Restart Handoff for October 21 read before startup guidance; VMs initially off per Joey. Snapshots were not reverted or renamed.
- Telemetry pod started by Joey: pfSense, DC, Wazuh, ELK, victim. Host available memory approximately 8% during this phase.
- pfSense syslogd stopped again: pgrep returned no process and GUI turned red. Operator restarted it. Marker SOC001-RESTART-20261021-06 reached ELK at displayed 06:40:41.315. Root cause unresolved.
- ELK endpoint export contains 984 records: victim 694, DC 290, displayed latest times 06:44:04 and 06:44:15. Export spans approximately 06:03–06:44; it is not a strict 15-minute sample.
- WAN static configuration observed: 10.10.40.5/24, WAN_STATIC 10.10.40.2 default; duplicate WAN_DHCP entry uses same gateway/monitor. No gateway changes made; dependency audit remains open.
- ELK shut down; VMware powered-off screenshot supplied. Host then showed 67% memory used. OpenVAS started for existing-report review; no new scan launched in this sequence.
- Existing report 9f80680d-9de8-4227-aa6d-b8471a682c34: Done, October 9 04:44:02–06:43:39 UTC, 1h59m37s. Complete QoD0 CSV/XML exports contain 57 matching result IDs for victim 10.10.20.20: 6 High, 4 Medium, 2 Low, 45 Log, no Critical. Earlier nine-result exports were filtered and superseded.
- Scanner consolidation explicitly confirms SMB login TRUE, registry access TRUE, missing registry permissions FALSE, WMI access FALSE. Two 320-second timeouts: WMI OS information and SMB hardware gathering. WMI file-share query also reported connection timeout.
- Current victim local WMI query passes; Winmgmt Running/Automatic; RemoteRegistry Running/Manual; profile DomainAuthenticated; scanner TCP 135 succeeds.
- All inspected built-in WMI rules disabled. Dedicated scanner-scoped WMI rule created and verified enabled. Subsequent remote OS query from ospd-openvas using wmiquery.py succeeded, build 19045. Screenshot evidence: codex-clipboard-c54dc1a9-0509-48cb-a6d8-32256811d2a0.png.

## Targeted Greenbone retest result

Config SOC-001 — Victim SMB-WMI validation was cloned from Base with three additional Windows NVTs: 96199 (WMI file shares), 108539 (SMB authentication success), and 108442 (LSC consolidation). Saved configuration showed three families and six explicitly selected NVTs; auto_enable_dependencies and safe_checks both Yes. The previously timed-out WMI OS test 96999 was not located or explicitly selected.

The new victim-only report ran October 21 13:42:22–13:54:02 UTC (07:42:22–07:54:02 MDT), 11m40s, Done. Complete CSV/XML contain 14 results, all Log, with report filter min_qod=0 and levels=chmlg. No XML error entries were returned. This narrowly scoped run is not a vulnerability clearance or a repeat of every failed test.

**Passed:** SMB login; registry access; Greenbone WMI file-share enumeration returned ADMIN$, C$, IPC$ without the former timeout. Direct Impacket WMI query had also passed. **Unresolved:** LSC consolidation still reports WMI/access_successful FALSE despite successful WMI share enumeration. Do not label all WMI coverage passed or assume this is merely a stale flag. Determine which VT sets that key and whether it ran before repeating tests or changing permissions.

Consolidation now reports full Windows build 10.0.19045.6466. However, the separate SMB Windows Full Build Number result contains a Notus error: Unable to process the response. Zero XML error entries therefore does not mean error-free processing. A certificate-derived hostname was reported not resolvable; scanner DNS remains a follow-up, not a proven cause of WMI behavior.

Raw source files: Downloads/SOC-001 Victim WMI retest 2026-10-21.csv and .xml. Keep original evidence private. Subsequent status-key investigation is recorded below.

## Remaining work

1. Identify a supported scanner connection-setting fix for native WMI, then validate consolidation. Successful share enumeration and explicit sign/seal queries do not close full scanner coverage.
2. Triage findings for applicability and confidence before remediation. Low-QoD findings are not confirmed exploitability.
3. Investigate recurring syslogd stop and sustained logging health; do not attribute it to gateway duplication or memory without evidence.
4. Retain pod strategy: ELK, Splunk, Kali and Shuffle off during current scanner work; recheck host headroom before additions.
5. Independent backup/restore testing and segmentation regression remain open.

## Native WMI diagnosis and maintenance preparation

### Feed refresh validation

Subsequent Feed Status screenshot confirms all four categories Current and no synchronization banner visible: NVT 20261021T0720, SCAP 20261020T0205, CERT 20261021T0425, GVMD_DATA 20261021T0512. Feed freshness GUI gate passed after the separate feed refresh. This does not establish closure of native scanner WMI behavior or validate every scanner function after maintenance.

Joey subsequently confirmed the custom SMB-WMI configuration and both historical reports remain accessible after the feed refresh. Preservation check passed. OpenVAS host package maintenance, reboot/runtime availability, GUI/report access, and feed freshness gates are complete within this validation scope. Native scanner WMI behavior remains unresolved; the explicit sign/seal CLI success is not a successful subsequent scanner retest.

Maintenance follow-up: Joey confirmed the powered-off pre-update OpenVAS snapshot complete. Reviewed upgrade simulation: 61 upgrades, no newly installed packages or removals, seven phased updates deferred. Supplied installation log followed by clear dpkg audit and dependency check; reboot-required flag present. After operator reboot, Docker/containerd active, gvmd and PostgreSQL healthy, GUI and both historical reports accessible. Initial post-reboot feeds were 13–14 days old; later refresh validation above supersedes that state. Added feed-freshness startup gate and separate download/import/validation procedure to phase-6-maintenance.md at Joey's request.

User supplied installed gb_wmi_access.nasl (OID 108205): it sets WMI/access_successful only after native wmi_connect succeeds. Scanner logs show native WMI connection failure during the targeted run at 13:53:04 UTC, and a later run at 16:46:44 UTC (later report not reviewed). Native wmic query without RPC binding options failed with NT_STATUS_ACCESS_DENIED. Victim System DistributedCOM event 10036 named SOCHOMELAB/SecAdmin and scanner 10.10.10.12, requesting RPC packet integrity. Generic client signing option did not resolve it.

Native wmic query with explicit target `//10.10.20.20[sign,seal]` then succeeded and returned build 19045. Impacket and WMI share enumeration had already succeeded. This establishes explicit signed/sealed native client connectivity; saved Greenbone scan behavior remains unchanged and consolidated WMI flag closure pending. Do not disable DCOM hardening or modify vendor feed scripts. OpenVAS reports 23.50.20 / gvm-libs 23.9.2; native wmic banner 4.0.0tp4-SVN-build-UNKNOWN does not establish the bundled openvas-smb release. No package inventory rows returned.

Joey confirmed no scans running before maintenance planning. The subsequently installed host transaction included Docker Engine/CLI/Compose/containerd, Filebeat 9.5.3 to 9.5.5, AppArmor, Netplan, Kerberos libraries and Ubuntu packages. OS package upgrades were separate from the later feed refresh. Other Linux VMs remain scheduled for separate maintenance turns under pod strategy.

## Evidence provenance

Ten selected screenshots were copied from temporary clipboard paths into the private project evidence archive `E:\PePesLab-SOC 2.0\Evidence\SOC-001\2026-10-21`, with SHA256 manifest. The [command/evidence companion](soc-001-command-evidence-2026-10-21.md) maps each screenshot to its purpose.

### OneNote synchronization status

October 8 notebook updates were previously verified. The October 21 handoff in PMO-000 was read successfully at session start. During the documentation closeout, OneNote reads repeatedly returned authentication requested/accepted without returning page data. Today's activities cannot yet be confirmed or synchronized to OneNote. Pending update: append a dated SOC-001 handoff to PMO-000 Reviews and Handoffs and add the activity/command-reference page in SOC 2.0 Daily Journal, preserving historical pages. Summarize telemetry recovery, native WMI sign/seal success versus pending scanner behavior, host/feed maintenance passed, remaining Linux patching/syslog stability issues, and link these Git records. No claim of notebook update is made until a write and read-back succeed.

Raw files remain private in Downloads. Reviewed complete report exports have suffix (2). CSV SHA256: 48471D4AD3ED6EA2A13CDCF5929A33E9B5CC53FB78816DD15F7BBF3E173D5D42. XML SHA256: 31718D9BD8B9E65265992554A8DEF6D035CEF0A2841B033B99F3FEE81B72B121. XML anonymizes the victim as 127.0.0.1; CSV and matching result IDs identify 10.10.20.20. No passwords recorded.

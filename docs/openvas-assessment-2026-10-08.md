# OpenVAS completed scan assessment — 2026-10-08

Report ID: 99e88a89-6f87-4156-b1a3-6233b5b839f5. Task ID: 4f2e170b-4324-449a-a6d9-7a93471e8ea6. Owner: Joey. Assessment: task execution complete; two-host authenticated coverage incomplete. No remediation applied by this assessment.

## Complete export reconciliation — supersedes initial filtered counts

Latest follow-up: direct SMB authentication and ADMIN$ directory listing succeeded from OpenVAS to the victim using the domain scan account, after the documented endpoint change. Current direct authentication passes; original scan coverage is unchanged. Greenbone's stored credential and registry/WMI LSC behavior still require scanner-side validation.

Follow-up: victim TCP445 initially timed out; RemoteRegistry was Disabled, and inspected SMB inbound rules were disabled under the Private profile. After RemoteRegistry Manual/start and the scanner-only inbound SMB exception, TCP445 succeeded from OpenVAS. Remote authentication still needs verification. See [change, future endpoint build and rollback](build-windows-endpoint-scan-readiness.md).

Replacement exports with filename suffix (1) explicitly set min_qod=0 and contain all 76 results in CSV and XML. Initial 72-result analysis below is historical context. Final totals: 3 High, 4 Medium, 3 Low, 66 Log; zero Critical. DC: 2 High, 3 Medium, 2 Low, 49 Log (56 total). Victim: 1 High, 1 Medium, 1 Low, 17 Log (20 total).

Additional findings: D(HE)ater Diffie-Hellman key-exchange DoS on TCP3389 for each host (CVSS7.5, QoD30), and Relative IP Identification number change on each host (CVSS2.6, QoD1). D(HE)ater reports TLS1.2 accepting TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 and TLS_DHE_RSA_WITH_AES_256_GCM_SHA384. Reported cipher support is evidence; successful DoS exploitation was not tested. Keep applicability/exposure validation open. IPID findings remain unvalidated due to very low QoD.

CSV SHA256: EE54443006BF41A573B5DA9E09CE3DE52826A0710B3DCF27AC3D3CE25917E652.
XML SHA256: 287C4746538512A881605A98C762568199CFD577B3BE8CDA38EF75506A285D99.

Export completeness passes. DC partial authenticated coverage and the victim authentication gap remain. Next: bounded victim SMB reachability and authentication checks, then finding validation. No full-scan rerun needed for export reconciliation.

## Initial filtered-export assessment (historical)

### Execution and evidence
Status Done. Scan start 2026-10-08T21:53:50Z; end 2026-10-09T01:22:06Z. America/Denver (MDT): October 8, 15:53:50–19:22:06. Elapsed 3h28m16s.

CSV contains 72 results. Anonymous XML reports 76 total, 72 filtered under min_qod=70. All severity levels including Log are represented. Four excluded results cannot be characterized from the supplied exports. Export again with min_qod=0; no scan rerun needed to recover existing report results.

Anonymous XML addresses map to actual CSV IPs through matching result IDs: 127.0.0.2 → DC10.10.20.10 (54 results); 127.0.0.1 → victim10.10.20.20 (18 results). They are anonymization placeholders, not unexpected scan targets.

Source filenames: report-99e88a89-6f87-4156-b1a3-6233b5b839f5.csv and .xml; retained privately in user Downloads, not copied to Git.
SHA256 CSV: 9B50E57282833927D998476540D5D52A9636BA5B2D87018A5D13101787CE929D.
SHA256 XML: 19FC9218B950379F436C7E88ACB6F5A7AB0AFD39DB001B96D5B02D93850C984C.

## Results
| Host | High | Medium | Low | Log | Exported total |
| --- | --- | --- | --- | --- | --- |
| DC10.10.20.10 | 1 | 3 | 1 | 49 | 54 |
| Victim10.10.20.20 | 0 | 1 | 0 | 17 | 18 |
| Total | 1 | 4 | 1 | 66 | 72 |

Zero Critical reported. These are scanner findings, not independent exploit confirmations; low finding counts do not establish host security.

## Authentication and coverage
DC: SMB NTLM login successful; registry and WMI access TRUE; missing registry permissions FALSE. Windows Server2019 Datacenter build17763 detected; successful local inventory/file-version checks present. Nevertheless, full build metadata remains unavailable and 28 checks timed out, so authentication success does not equal complete coverage.

Victim: no successful SMB login or LSC consolidation result in supplied exports. Inventory is chiefly remote RDP/TLS detection, with OS inferred from network fingerprinting. Authenticated coverage not demonstrated; not enough evidence to label credentials invalid. Check victim port445/service/firewall/domain permissions and review QoD0 export before changing account privileges.

## Duration and errors
Victim host interval: 21:54:48Z–22:02:33Z, 7m45s.
DC interval: 21:54:48Z–01:21:57Z, 3h27m09s.
All 28 XML errors map to DC: 25 timed out at320s; three at900s (Log4j, Spring Boot, Spring Framework detection). Examples include WMI OS/file-share queries, Windows Services Start, Defender detection, application inventory, full build, and cleanup of a deprecated authenticated-scan support service.

The DC dominated duration. Do not add timeout values as sequential runtime: checks may overlap. Defender detection/remediation during this scan is independently verified in Wazuh, consistent with potential command-check interference; a causal explanation for every timeout is not established.

The cleanup-check timeout warrants a read-only review for residual scan support services or artifacts before any deletion. No artifacts are presumed to exist.

## Non-log findings and disposition
| Host | Finding | Scanner CVSS / QoD | Assessment / next action |
| --- | --- | --- | --- |
| DC | Windows IExpress untrusted search path; CVE-2018-0598 | 7.8 /80 | Presence-based IEXPRESS.EXE check, not exploitation. Validate use/exposure and safe archive handling; do not delete Windows binaries from this finding. |
| DC | HID/USB code execution; CVE-2011-0638 | 6.9 /80 | hidserv.dll presence check. Assess physical/USB passthrough exposure and device controls; not proof of remote compromise. |
| DC | DCE/RPC and MSRPC enumeration TCP135 | 5.0 /80 | RPC endpoints enumerated. Review approved-source access; DC depends on RPC, so do not blanket-disable it. |
| DC and victim | Deprecated TLS1.0/1.1 on RDP TCP3389 | 4.3 /98 each | Direct protocol evidence. Plan controlled TLS hardening with RDP compatibility and rollback verification. Referenced CVEs do not independently prove every listed CVE applies. |
| DC | Snipping Tool information disclosure; CVE-2023-28303 | 3.3 /80 | Version10.0.17763.1697 compared with11.2302.20.0. Validate product/OS applicability before applying a cross-version threshold or declaring true/false positive. |

## Actions and acceptance
1. Re-export existing completed report at QoD0 and reconcile all76 results.
2. Investigate victim SMB reachability/authentication with bounded read-only checks.
3. Review DC timeout causes and possible cleanup remnants while preserving Defender.
4. Validate finding applicability; prioritize controlled RDP TLS hardening after compatibility checks.
5. Capture final report review and keep segmentation/recovery validation separately tracked.

Success: complete exports reconciled; per-host authenticated status explicit; timeouts triaged; findings disposition documented; remediation verified with focused retests rather than repeated blind full scans.

Related: [Defender validation](defender-telemetry-validation-2026-10-08.md), [firewall record](firewall-policy-and-aliases.md), [recovery reference](recovery-runbook-reference.md). NIST CSF: Identify/Protect/Detect; no compliance certification implied.

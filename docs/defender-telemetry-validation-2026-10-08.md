# Defender telemetry validation — 2026-10-08

Owner: Joey. Status: passed for observed DC event pairs. Evidence: user-supplied DC Event Viewer and Wazuh screenshots on October 8, 2026. Times below are displayed dashboard times; raw UTC timestamps were not inspected.

## Result

DC agent 002 (10.10.20.10, soc-adsrv-win19) delivered Defender Operational events that generated Wazuh alerts and appeared in the dashboard. A channel-filtered search over Last 24 hours returned 23 hits. This verifies collection, transport, rule matching, and dashboard visibility for the observed events.

| Dashboard time | Event ID | Wazuh rule ID | Behavior |
| --- | --- | --- | --- |
| 15:56:35.852 | 1116 | 62123 | Antimalware platform detected potentially unwanted software |
| 15:56:51.600 | 1117 | 62124 | Antimalware platform performed a protective action |
| 16:03:06.052 | 1116 | 62123 | Second detection alert |
| 16:03:20.569 | 1117 | 62124 | Second protective-action alert |

The DC Event Viewer showed the first detection at 15:56:34 and remediation at 15:56:51 for VirTool:Win32/Impacket.D. The earlier Wazuh detail screenshot showed Remove, no additional actions required, and successful operation for the first remediation record. The second pair's action outcome has not been inspected.

## Limits and risks

This does not establish every Defender event is collected, measured delivery latency, notification delivery, or an analyst response SLA. The prior empty Last 30 minutes search is resolved; its cause remains unconfirmed. Scan-period correlation does not independently establish originating host or explain every scan timeout. No Defender exclusion or protection disablement was applied as part of this validation.

## Next actions

Complete the OpenVAS task, export its final report, and assess target authentication, coverage, and errors. Retain original screenshots privately and prepare reviewed portfolio evidence. NIST CSF alignment: Detect and Respond. This is a focused functional validation, not a full control assessment.

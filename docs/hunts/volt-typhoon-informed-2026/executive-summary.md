# SOC home lab threat hunt executive summary

**TLP:CLEAR**

Report date: October 3, 2026 | Case: SOC-HUNT-2026-001 | Audience: lab management and decision makers

## Executive Summary

The hunt examined whether unauthorized use of legitimate administration tools, accounts, and persistence mechanisms was present in the SOC home lab, using behavior described in public Volt Typhoon guidance. No confirmed compromise was identified in the reviewed evidence, so the hypothesis was not supported; it was not conclusively disproved because earlier activity was incompletely recorded. The observed activity was consistent with recognized user actions, security-agent checks, and software maintenance, with one Defender validation issue requiring operational follow-up. The investigation repaired missing log delivery and incorrect firewall timestamps, enabled additional auditing, and disabled a broad firewall rule that overrode more specific rules. The remaining priorities are to finish network segmentation, validate the new auditing, and improve historical evidence coverage before treating future empty searches as assurance.

## Decisions and outcomes

| Area | Outcome | Management implication |
| --- | --- | --- |
| Compromise hypothesis | Unproven; no confirmed malicious activity in reviewed evidence | No basis for Volt Typhoon attribution or a confirmed incident declaration |
| Monitoring | Direct Windows log delivery restored and verified; additional auditing enabled | Future hunts have better evidence, but missing historical events are not recovered |
| Firewall | Logging verified; timestamps aligned after reboot; broad allow-all rule disabled | Specific Corporate rule now handles new test traffic; full segmentation remains incomplete |
| Defender validation | Microsoft-signed file failed a protected-process requirement | Follow up as a signing/compatibility candidate; no evidence of modification established |
| Persistence review | Task history aligns with maintenance; no service installations returned in the latest seven-day check | Confidence is limited by retained history and absence of full historical task definitions |

## Priority actions

1. Replace broad inter-network permissions with a tested access plan that preserves administration and telemetry.
2. Validate scheduled-task auditing and delivery using a harmless temporary task, and confirm audit settings persist after policy refresh.
3. Investigate the Defender signing mismatch and watch for recurrence without weakening Defender protection.
4. Preserve the evidence package in the restricted central knowledge base and establish regular collection-health checks.

The detailed report contains the commands, searches, observed results, confidence levels, and evidence references. The scope was a home-lab assessment, not a forensic investigation of a confirmed intrusion or an assessment of real critical infrastructure.

**TLP:CLEAR**

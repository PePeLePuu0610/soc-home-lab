# ELK Log Ingestion Plan

**Goal:** get alll five log sources — Wazuh, pfSense, Suricata, OpenVAS, and Windows — flowing into ELK, with a clear pass/fail gate per source, before moving on to SOAR (Step 3.9). Full step-by-step commands for every objective live in [Configure Log Forwarding](configure-log-forwarding.md); this document is the plan and sign-off layer that sits above it — what to do, in what order, and how you'll know each one is actually done.

This scope is deliberately **ELK-only for now**. Splunk already receives Wazuh and pfSense/Suricata (Parts 1-4 of the forwarding guide cover both destinations at once), but OpenVAS→Splunk and Windows→Splunk are follow-up work once the ELK side is proven out — no sense building the same thing twice before confirming it once.

## Objectives

| # | Source | Destination index | Method | Guide section |
|---|---|---|---|---|
| 1 | Wazuh | `wazuh-alerts-*` | Native `syslog_output` | [Part 1](configure-log-forwarding.md#part-1-wazuh-both-siems-native-syslog_output) |
| 2 | pfSense | `pfsense-suricata-*` | Built-in remote syslog | [Part 2.2](configure-log-forwarding.md#22-configure-pfsenses-remote-syslog-forwarding) |
| 3 | Suricata | `pfsense-suricata-*` | "Send Alerts to System Log" + pfSense's syslog forwarding | [Part 2.1](configure-log-forwarding.md#21-enable-suricata-alerts-to-the-system-log) |
| 4 | OpenVAS | `openvas-scans-*` | Custom `python-gvm` export script + Filebeat | [Part 5](configure-log-forwarding.md#part-5-openvas-elk) |
| 5 | Windows (victim + AD) | `windows-events-*` | Winlogbeat | [Part 6](configure-log-forwarding.md#part-6-windows-elk-via-winlogbeat) |

## Sequencing — easiest and most-ready first, riskiest last

This isn't arbitrary ordering — it's a deliberate risk-management call, same principle as building pfSense before Kali back in Phase 3:

1. **Wazuh** — the `syslog_output` config was already worked out before the Wazuh rebuild; this is mostly re-running steps already known to work on the new Ubuntu 24.04 box.
2. **pfSense + Suricata** — fully documented already, straightforward UI configuration, no new technology introduced.
3. **Windows (Winlogbeat)** — new to this lab, but Winlogbeat is Elastic's own stable, long-established shipper. Low risk despite being new.
4. **OpenVAS** — saved for last on purpose. No native export mechanism exists, the ready-made community tools have known reliability problems, and the approach in this guide (a custom script against Greenbone's GMP API) is the least-trodden path of the five. Expect this one to take longer and possibly need real debugging — better to hit that after the other four are already confirmed working and out of the way.

## Exit Gate per Objective

Each gate is a specific, checkable pass/fail condition — not "it should be working," an actual thing you can point at.

### Gate 1 — Wazuh → ELK

**Pass condition:** generate a test alert (a few failed SSH/RDP logins against the Windows victim), and within 2 minutes it appears in Kibana's `wazuh-alerts-*` data view with parsed fields (not one giant unparsed string).

### Gate 2 — pfSense → ELK

**Pass condition:** any normal firewall log line (e.g. a blocked connection attempt) appears in Kibana's `pfsense-suricata-*` data view within 2 minutes of it happening.

### Gate 3 — Suricata → ELK

**Pass condition:** run a quick Nmap scan from Kali against the Windows victim; a corresponding Suricata alert appears in the same `pfsense-suricata-*` data view within 2 minutes.

### Gate 4 — OpenVAS → ELK

**Pass condition:** after manually running `gvm-export.py` following a completed scan, at least one result document appears in Kibana's `openvas-scans-*` data view with recognizable fields (`name`, `host`, `severity`, `threat`). The cron schedule running unattended for at least one full cycle without manual intervention is the secondary, "actually done" condition — the manual run proves the mechanism works, the unattended cycle proves it's actually production-ready for this lab.

### Gate 5 — Windows → ELK

**Pass condition:** both the Windows victim and the AD server show events in Kibana's `windows-events-*` data view, distinguishable from each other via the `winlog.computer_name` field — not just one of the two machines reporting.

## Overall Phase Exit Gate

All five individual gates above pass, **and**:

- [ ] All five data views exist in Kibana and were verified with real, freshly-generated traffic (not just leftover test data from earlier troubleshooting)
- [ ] The [Configure Log Forwarding](configure-log-forwarding.md) exit criteria checklist is fully checked for the ELK column
- [ ] `docs/index.md`'s Current Status table is updated to reflect ELK ingestion as complete

Once all of that is true, Step 3.9 (SOAR/Shuffle) is unblocked — see [Phase 3 Implementation](phase-3-implementation.md#step-39-soar).

## What's deliberately out of scope here

- **Splunk ingestion for OpenVAS and Windows** — noted as follow-up work in the forwarding guide, not blocking this phase gate.
- **Full EVE JSON from Suricata** — this plan uses the simpler, confirmed-working alert-summary method (see the forwarding guide's "Before you start" section for why); richer packet-level detail via the community pfELK project is a possible later enhancement, not a requirement here.
- **Kibana dashboards/visualizations** — getting data *into* the five indices is this phase's job; building dashboards on top of it is naturally Phase 4 (Testing) territory, once there's real data to visualize.

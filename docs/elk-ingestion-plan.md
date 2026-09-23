# ELK Log Ingestion Plan

**Goal:** get all five log sources — Wazuh, pfSense, Suricata, OpenVAS, and Windows — flowing into ELK, with a clear pass/fail gate per source, with Gates 1–3 used as the initial prerequisite for SOAR (Step 3.9) and Gates 4–5 retained as follow-ups. Full step-by-step commands for every objective live in [Configure Log Forwarding](configure-log-forwarding.md); this document is the plan and sign-off layer that sits above it — what to do, in what order, and how you'll know each one is actually done.

This scope is deliberately **ELK-only for now**. Splunk already receives Wazuh and pfSense/Suricata (Parts 1-4 of the forwarding guide cover both destinations at once), but OpenVAS→Splunk and Windows→Splunk are follow-up work once the ELK side is proven out — no sense building the same thing twice before confirming it once.

## Objectives

| # | Source | Destination index | Method | Guide section |
|---|---|---|---|---|
| 1 | Wazuh | `wazuh-alerts-*` | Native `syslog_output` | [Part 1](configure-log-forwarding.md#part-1-wazuh-both-siems-native-syslog_output) |
| 2 | pfSense | `pfsense-*` | Built-in remote syslog (UDP 5514) | [Part 2.2](configure-log-forwarding.md#22-configure-pfsenses-remote-syslog-forwarding) |
| 3 | Suricata | `pfsense-*` (shares pfSense's receiver and index — not separated) | "Send Alerts to System Log" + pfSense's syslog forwarding | [Part 2.1](configure-log-forwarding.md#21-enable-suricata-alerts-to-the-system-log) |
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

### Gate 1 — Wazuh → ELK ✅ PASSED

**Pass condition:** generate a test alert (a few failed SSH/RDP logins against the Windows victim), and within 2 minutes it appears in Kibana's `wazuh-alerts-*` data view with parsed fields (not one giant unparsed string).

**Evidence:** manager alert (agent `000`, rule `5502`) and Windows endpoint alert (agent `001`, `soc-vict-win10`, rule `60602`) both confirmed in Kibana with structured `agent`/`rule` fields and no parse-failure tags. Required adding `<format>json</format>` to the ELK `syslog_output` block. See [Integration and Validation §3](integration-validation.md#3-integrated-wazuh-elk).

### Gate 2 — pfSense → ELK ✅ PASSED

**Pass condition:** any normal firewall log line (e.g. a blocked connection attempt) appears in Kibana's `pfsense-*` data view within 2 minutes of it happening.

**Evidence:** UDP marker test confirmed in Kibana, then real firewall traffic confirmed, then re-confirmed after debug output was removed and the service restarted. See [Integration and Validation §2](integration-validation.md#2-verified-pfsense-elk).

### Gate 3 — Suricata → ELK ✅ PASSED

**Pass condition:** a deliberately triggered IDS detection appears in the `pfsense-*` data view within 2 minutes.

**Evidence:** service start/stop messages were explicitly rejected as insufficient proof of detection. A temporary rule (SID `1000001`, ICMP echo from `10.10.20.20` to `10.10.20.5`) was added to produce a deterministic alert, triggered with `ping -n 4` from the Windows victim, and confirmed in Kibana with matching SID, source, and destination. **Open item:** remove SID `1000001` and restart the Corporate interface instance. See [Integration and Validation §4](integration-validation.md#4-verified-suricata-elk).

### Gate 4 — OpenVAS → ELK ⏸ NOT STARTED

Note that Step 3.8's own requirement (run a scan, produce a report) **is** met — a completed scan of `10.10.20.20` was reviewed in Greenbone's own UI, documented in [Integration and Validation §6](integration-validation.md#6-verified-openvas-scanning-and-report-generation). What remains open is *shipping those results into ELK*, which is this gate's separate concern.

**Pass condition:** after manually running `gvm-export.py` following a completed scan, at least one result document appears in Kibana's `openvas-scans-*` data view with recognizable fields (`name`, `host`, `severity`, `threat`). The cron schedule running unattended for at least one full cycle without manual intervention is the secondary, "actually done" condition — the manual run proves the mechanism works, the unattended cycle proves it's actually production-ready for this lab.

### Gate 5 — Windows → ELK ⏸ NOT STARTED (partially satisfied by another path)

**Judgment call worth making deliberately:** Windows telemetry *does* already reach ELK — via the Wazuh agent on `soc-vict-win10` (agent `001`), confirmed under Gate 1 with Windows rule `60602` visible in Kibana. If the objective is "Windows security events are visible in ELK," that's arguably already met.

This gate covers the *different* capability of shipping **raw Windows Event Logs** via Winlogbeat — Wazuh sends curated, rule-matched alerts; Winlogbeat sends everything. For a portfolio, having both is worth something: it demonstrates curated SIEM alerting and raw log-hunting side by side. It is not required for SOAR to function.

**Pass condition:** both the Windows victim and the AD server show events in Kibana's `windows-events-*` data view, distinguishable from each other via the `winlog.computer_name` field — not just one of the two machines reporting.

## Overall Phase Exit Gate

**Status: Gates 1–3 passed. Gates 4–5 open.**

- [x] Wazuh, pfSense, and Suricata verified in ELK with freshly-generated traffic
- [x] Same three sources additionally verified in Splunk (see [Integration and Validation §5](integration-validation.md#5-configured-and-verified-splunk-ingestion))
- [ ] OpenVAS results shipping into `openvas-scans-*`
- [ ] Winlogbeat shipping raw Windows events into `windows-events-*`
- [ ] Security debt cleared: remove temporary Suricata SID `1000001`; replace the Elasticsearch certificate-verification bypass with trusted CA verification; define index retention

### Is SOAR unblocked?

**Step 3.9 is now validated.** The implemented workflow receives JSON directly from Wazuh and calls the Wazuh API for endpoint response. ELK and Splunk remain parallel log destinations, not dependencies of that execution path. See [Shuffle validation](build-shuffle.md).

Gates 4 and 5 are **additive coverage, not blockers**: OpenVAS results are periodic scan findings rather than real-time alerts, and raw Windows event logs duplicate a path Wazuh already covers in curated form. Treat them as follow-up work that can proceed in parallel with, or after, Step 3.9 — see [Phase 3 Implementation](phase-3-implementation.md#step-39-soar).

The security-debt items above are the ones genuinely worth clearing sooner rather than later, since a leftover test IDS rule will generate noise that muddies Phase 4's attack-simulation testing.

## What's deliberately out of scope here

- **Splunk ingestion for OpenVAS and Windows** — noted as follow-up work in the forwarding guide, not blocking this phase gate.
- **Full EVE JSON from Suricata** — this plan uses the simpler, confirmed-working alert-summary method (see the forwarding guide's "Before you start" section for why); richer packet-level detail via the community pfELK project is a possible later enhancement, not a requirement here.
- **Kibana dashboards/visualizations** — getting data *into* the five indices is this phase's job; building dashboards on top of it is naturally Phase 4 (Testing) territory, once there's real data to visualize.

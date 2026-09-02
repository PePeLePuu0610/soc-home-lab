# Home SOC Lab — Project Documentation

A self-contained Security Operations Center (SOC) lab built on a single Windows host with VMware Workstation Pro, simulating an enterprise detection-and-response environment end to end: firewall-segmented network zones, dual SIEMs, host and network intrusion detection, vulnerability management, and SOAR-driven automated response.

**Host specs:** 11th Gen Intel i7-1185G7 @ 3.00GHz | 32GB RAM | 1TB SSD
**Methodology:** Waterfall — each phase is completed and signed off before the next begins.

## Current Status

| Component | Status |
|---|---|
| pfSense + Suricata | ✅ Running, no errors — all traffic currently allowed (hardening deferred to Phase 5) |
| Windows victim + AD server | ✅ Built, Wazuh agents installed and reporting |
| Wazuh | ✅ Rebuilt from scratch on Ubuntu 24.04 (replacing the original OVA) — running, dashboards accessible, auditing endpoints |
| OpenVAS | ✅ Scans completing successfully, reports visible in-dashboard |
| ELK Stack | ⚠️ Running, login working — **no log data flowing yet** (integration in progress) |
| Splunk Enterprise | ⚠️ Running, login working — **no log data flowing yet** (integration in progress) |
| Log forwarding (Wazuh/pfSense/Suricata → ELK & Splunk) | 🔄 In progress — see [Configure Log Forwarding](configure-log-forwarding.md) |
| SOAR (Shuffle) | ⏸ Not started — blocked on log forwarding completion per Waterfall sequencing |

## Project Phases

| Phase | Focus |
|---|---|
| [Phase 1 — Requirements & Planning](phase-1-requirements.md) | Scope, hardware budget, success criteria, ISO/software checklist |
| [Phase 2 — Design](phase-2-design.md) | Network zones, IP addressing, data flow, naming convention |
| [Phase 3 — Implementation](phase-3-implementation.md) | Step-by-step build order for every VM |
| ↳ [Build Guide: ELK Stack](build-elk-stack.md) | Detailed Elasticsearch + Kibana + Logstash build, with troubleshooting |
| ↳ [Build Guide: Splunk Enterprise](build-splunk-enterprise.md) | Detailed Splunk Enterprise build |
| ↳ [Build Guide: OpenVAS](build-openvas.md) | Detailed Greenbone/OpenVAS vulnerability scanner build |
| ↳ [Configure Log Forwarding](configure-log-forwarding.md) | Wazuh, pfSense, and Suricata → both ELK and Splunk |
| [Phase 4 — Testing & Verification](phase-4-testing.md) | End-to-end attack/detection/response test matrix |
| [Phase 5 — Deployment](phase-5-deployment.md) | Snapshots, hardening, go-live checklist |
| [Phase 6 — Maintenance](phase-6-maintenance.md) | Ongoing patching and skills-building cadence |

## Why This Project Exists

This lab doubles as a hands-on portfolio piece: every phase produces something demonstrable — firewall rule sets, SIEM dashboards, detection alerts, vulnerability reports, and automated SOAR playbooks — aimed at building and showing real SOC analyst skills using entirely free, open-source tooling.

## Repository Layout

```text
soc-home-lab/
├── docs/            # This documentation site (built with MkDocs)
├── configs/          # Exported configs: pfSense rules, Wazuh rules, Suricata rules, docker-compose files
├── screenshots/       # Portfolio evidence — dashboards, alerts, playbook runs
└── .github/workflows/  # CI/CD: docs linting, link checking, GitHub Pages deploy
```

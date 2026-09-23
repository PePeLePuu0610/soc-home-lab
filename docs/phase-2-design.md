## PHASE 2 — Design

**Goal:** Design the network and naming scheme on paper before building anything.

### 2.1 Network Zones

Enterprise SOCs separate networks into zones so an attacker in one zone can't freely reach another. You'll simulate this with VMware's **virtual networks** (VMnet) and pfSense as the router between them.

![SOC lab network diagram: Internet through pfSense WAN interface, fanning out to Management, Corporate, and Attacker LAN zones](assets/network-zone-diagram.svg)

*Internet reaches pfSense's WAN interface, which routes out to three isolated LAN interfaces — one per zone below.*

| Zone | VMware Network | Subnet | Who lives here |
|---|---|---|---|
| WAN (simulated internet) | NAT (VMnet8) | Reserved DHCP lease | pfSense's WAN interface only |
| Management | Host-only (VMnet1) | 10.10.10.0/24 | SIEMs, Wazuh, OpenVAS, SOAR, management endpoint — the tools *you* use |
| Corporate LAN | Host-only (VMnet2) | 10.10.20.0/24 | Windows Server (AD), Windows victim VM |
| Attacker Zone | Host-only (VMnet3) | 10.10.30.0/24 | Kali |

pfSense gets one virtual network adapter per zone (4 total) and acts as the router/firewall between all of them — this is exactly how a real network's edge firewall works, just scaled down.

### 2.2 VM Inventory & IP Address Plan

This is the authoritative, as-built reference — kept in sync with actual builds, not just the original plan.

| VM Name | Role | RAM | vCPU | Disk | IP Address | OS |
|---|---|---|---|---|---|---|
| SOC-FW-pfSense | Firewall/router | 2GB | 2 | 80GB | WAN: reserved DHCP lease (`10.10.40.101`) · Mgmt: `10.10.10.5/24` · Corp: `10.10.20.5/24` · Attacker: `10.10.30.5/24` | FreeBSD |
| SOC-atk-Kali | Attacker | 4GB | 4 | 40GB | `10.10.30.10/24` | Kali 2026.2 |
| SOC-Vict-Win10 | Corp victim | 4GB | 2 | 60GB | `10.10.20.20/24` | Windows 10 |
| SOC-ADSRV-Win19 | Domain Controller | 4GB | 2 | 60GB | `10.10.20.10/24` | Windows Server 2019 Standard (not activated) |
| SOC-SIEM-ELK | SIEM #1 | 8GB | 4 | 100GB | `10.10.10.10/24` | Ubuntu 24.04 |
| SOC-SIEM-Splunk | SIEM #2 | 6GB | 2 | 100GB | `10.10.10.14/24` | Ubuntu 24.04 |
| SOC-XDR-Wazuh | HIDS/XDR | 6GB | 4 | 100GB | `10.10.10.11/24` | Ubuntu 24.04 |
| SOC-Vuln-OpenVAS | Vulnerability scanner | 6GB | 2 | 100GB | `10.10.10.12/24` | Ubuntu 24.04 |
| soc-soar-shfl | SOAR | 8GB | 4 | ~100GB | `10.10.10.13/24` | Ubuntu 24.04.5 LTS |
| *Management Endpoint (planned)* | Analyst workstation | — | — | — | `10.10.10.15/24` | KDE Linux (planned) |

> **As-built notes:** LAN gateways remain `.5`. Wazuh was rebuilt on Ubuntu 24.04 and includes its Indexer; the internal indexing path was retained. The actual Shuffle hostname is `soc-soar-shfl`. Disk values are configured capacities, not consumed SSD space. Only Pod A is routinely powered on; other VMs are enabled for each task. See [hardware budget](phase-1-requirements.md#13-critical-constraint-your-hardware-budget). The management endpoint remains planned.

### 2.3 Data Flow Design

Attack traffic path: **Kali (10.10.30.10) → pfSense → Windows victim (10.10.20.20)**
Detection path: **Windows victim (Wazuh agent) + pfSense (IDS) → logs forwarded → SIEM (10.10.10.10)**
Validated response path: **Windows Application event → Wazuh manager → Shuffle webhook → marker condition → Wazuh API → agent 001 → marker file**. Reversal is a separate manually started Shuffle workflow. ELK and Splunk remain parallel ingestion destinations; neither SIEM triggers this playbook.

### 2.4 Naming Convention

Use a consistent prefix so VMs are easy to identify in VMware's library: `SOC-<role>-<os>`, e.g. `SOC-FW-pfSense`, `SOC-SIEM-ELK`, `SOC-Vict-Win10`, `SOC-atk-Kali`, `SOC-ADSRV-Win19`, `SOC-XDR-Wazuh`, `SOC-Vuln-OpenVAS` — see the inventory table in 2.2 for the full current list.

### Exit Criteria for Phase 2

- [ ] Network diagram (zones + subnets) written down
- [ ] IP address table completed
- [ ] Naming convention chosen

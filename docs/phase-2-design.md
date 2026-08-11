## PHASE 2 — Design

**Goal:** Design the network and naming scheme on paper before building anything.

### 2.1 Network Zones
Enterprise SOCs separate networks into zones so an attacker in one zone can't freely reach another. You'll simulate this with VMware's **virtual networks** (VMnet) and pfSense as the router between them.

![SOC lab network diagram: Internet through pfSense WAN interface, fanning out to Management, Corporate, and Attacker LAN zones](assets/network-zone-diagram.svg)

*Internet reaches pfSense's WAN interface, which routes out to three isolated LAN interfaces — one per zone below.*

| Zone | VMware Network | Subnet | Who lives here |
|---|---|---|---|
| WAN (simulated internet) | NAT (VMnet8) | DHCP from host | pfSense's WAN interface only |
| Management | Host-only (VMnet1) | 10.10.10.0/24 | SIEMs, Wazuh, OpenVAS, SOAR — the tools *you* use |
| Corporate LAN | Host-only (VMnet2) | 10.10.20.0/24 | Windows Server (AD), Windows victim VM |
| Attacker Zone | Host-only (VMnet3) | 10.10.30.0/24 | Kali |

pfSense gets one virtual network adapter per zone (4 total) and acts as the router/firewall between all of them — this is exactly how a real network's edge firewall works, just scaled down.

### 2.2 IP Address Plan
| Device | Zone | IP |
|---|---|---|
| pfSense WAN | NAT | DHCP |
| pfSense LAN interfaces | Mgmt / Corp / Attacker | 10.10.10.1 / 10.10.20.1 / 10.10.30.1 |
| SIEM (ELK or Splunk) | Management | 10.10.10.10 |
| Wazuh manager | Management | 10.10.10.11 |
| OpenVAS | Management | 10.10.10.12 |
| SOAR | Management | 10.10.10.13 |
| Windows Server (AD) | Corp | 10.10.20.10 |
| Windows victim | Corp | 10.10.20.20 |
| Kali | Attacker | 10.10.30.10 |

### 2.3 Data Flow Design
Attack traffic path: **Kali (10.10.30.10) → pfSense → Windows victim (10.10.20.20)**
Detection path: **Windows victim (Wazuh agent) + pfSense (IDS) → logs forwarded → SIEM (10.10.10.10)**
Response path: **SIEM alert → SOAR → automated action back on Windows Server/victim**

### 2.4 Naming Convention
Use a consistent prefix so VMs are easy to identify in VMware's library: `SOC-<role>-<os>`, e.g. `SOC-FW-pfSense`, `SOC-SIEM-ELK`, `SOC-VICTIM-Win11`, `SOC-ATK-Kali`.

### Exit Criteria for Phase 2
- [ ] Network diagram (zones + subnets) written down
- [ ] IP address table completed
- [ ] Naming convention chosen

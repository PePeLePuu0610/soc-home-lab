## PHASE 2 — Design

**Goal:** Design the network and naming scheme on paper before building anything.

### 2.1 Network Zones

Enterprise SOCs separate networks into zones so an attacker in one zone can't freely reach another. You'll simulate this with VMware's **virtual networks** (VMnet) and pfSense as the router between them.

![SOC lab network diagram: Internet through pfSense WAN interface, fanning out to Management, Corporate, and Attacker LAN zones](assets/network-zone-diagram.svg)

*Internet reaches pfSense's WAN interface, which routes out to three isolated LAN interfaces — one per zone below.*

| Zone | VMware Network | Subnet | Who lives here |
|---|---|---|---|
| WAN (simulated internet) | NAT (VMnet8) | DHCP from host | pfSense's WAN interface only |
| Management | Host-only (VMnet1) | 10.10.10.0/24 | SIEMs, Wazuh, OpenVAS, SOAR, management endpoint — the tools *you* use |
| Corporate LAN | Host-only (VMnet2) | 10.10.20.0/24 | Windows Server (AD), Windows victim VM |
| Attacker Zone | Host-only (VMnet3) | 10.10.30.0/24 | Kali |

pfSense gets one virtual network adapter per zone (4 total) and acts as the router/firewall between all of them — this is exactly how a real network's edge firewall works, just scaled down.

### 2.2 IP Address Plan

| Device | Zone | IP |
|---|---|---|
| pfSense WAN | NAT | DHCP |
| pfSense LAN interfaces | Mgmt / Corp / Attacker | 10.10.10.5 / 10.10.20.5 / 10.10.30.5 |
| SIEM ELK | Management | 10.10.10.10 |
| Wazuh manager | Management | 10.10.10.11 |
| OpenVAS | Management | 10.10.10.12 |
| SOAR | Management | 10.10.10.13 |
| SIEM Splunk | Management | 10.10.10.14 |
| Management Endpoint (KDE Linux) | Management | 10.10.10.15 |
| Windows Server (AD) | Corp | 10.10.20.10 |
| Windows victim | Corp | 10.10.20.20 |
| Kali | Attacker | 10.10.30.10 |

> **Note:** pfSense's LAN interface addresses were changed from `.1` to `.5` on each subnet after initial planning — every VM's default gateway and DNS server should point at the `.5` address on its zone. The original plan assigned one shared address for "SIEM (ELK or Splunk)," under the assumption you'd swap them in one at a time per the pod strategy in Phase 1; since both are built as permanent VMs running side by side for direct comparison, they now have distinct addresses. A **Management Endpoint (KDE Linux)** VM was also added at `10.10.10.15` — an analyst workstation living in the Management zone rather than a monitored asset, distinct from the Corp-zone Windows victim. **Wazuh manager is deployed from Wazuh's official OVA appliance** (confirmed built on Amazon Linux 2023), not cloned from the Ubuntu 22.04 template used for every other VM in this lab — worth remembering any time a build step assumes `apt`, since that VM uses `yum` instead. See [Configure Log Forwarding](configure-log-forwarding.md) for where this mattered in practice.

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

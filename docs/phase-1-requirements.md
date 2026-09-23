## PHASE 1 — Requirements & Planning

**Goal:** Decide exactly what this lab needs to do before touching VMware.

### 1.1 Project Objective

Build a self-contained enterprise-style security environment that lets you practice the full SOC (Security Operations Center) workflow: an attack happens → a sensor detects it → a SIEM (Security Information and Event Management tool — collects and analyzes logs) shows it → you investigate → you respond.

### 1.2 In-Scope Components

| Component | Purpose | Category |
|---|---|---|
| pfSense | Firewall/router — separates and controls traffic between network zones | Network isolation |
| Elastic Stack (ELK) | Log collection, search, dashboards | SIEM #1 |
| Splunk Enterprise (free dev license) | Log collection, search, dashboards | SIEM #2 |
| Wazuh | Host-based intrusion detection (HIDS) + basic XDR (Extended Detection & Response) | Endpoint monitoring |
| Suricata | Network Intrusion Detection System (IDS) — watches network traffic for attack patterns. **Decision made:** installed as a pfSense package rather than a standalone VM, for simplicity | Network monitoring |
| OpenVAS (Greenbone) | Vulnerability scanning | Vulnerability management |
| SOAR — **Shuffle** (decided) | Security Orchestration, Automation and Response — automates your response steps | Response automation |
| Kali Linux | Attacker machine used to generate real traffic/attacks to detect | Attack simulation |
| Windows 10/11 + Windows Server (AD) | "Victim" machines representing a real corporate network | Target environment |
| Management Endpoint (KDE Linux) | Analyst workstation living in the Management zone, added after initial planning | Analyst tooling |

### 1.3 Critical Constraint: Your Hardware Budget

| VM | RAM | vCPU | Configured disk capacity |
|---|---|---|---|
| pfSense / Suricata | 2 GB | 2 | 80 GB |
| Kali | 4 GB | 4 | 40 GB |
| Windows 10 victim | 4 GB | 2 | 60 GB |
| Windows Server 2019 / AD | 4 GB | 2 | 60 GB |
| ELK | 8 GB | 4 | 100 GB |
| Splunk | 6 GB | 2 | 100 GB |
| Wazuh, including Indexer | 6 GB | 4 | 100 GB |
| OpenVAS | 6 GB | 2 | 100 GB |
| Shuffle | 8 GB | 4 | Approximately 100 GB (98 GB filesystem observed) |
| **Total** | **48 GB** | — | **Approximately 740 GB** |

These are the operator-reported current allocations; disk capacity is not physical consumption. The host has 32GB RAM and a dedicated 500GB external SSD for the VMs. Approximately 197GB was free before Shuffle deployment; current free space has not been remeasured. Thin provisioning does not prevent eventual capacity exhaustion.

- **Pod A — routine core:** pfSense + one Windows victim + Wazuh = 12GB.
- **SIEM sessions:** add ELK (8GB) or Splunk (6GB) as needed. Both together with Pod A total 26GB, leaving only 6GB for the host.
- **SOAR sessions:** Pod A + Shuffle = 20GB. Keep ELK, Splunk, OpenVAS, Kali, and the additional AD VM off unless needed.
- **Scan sessions:** Pod A + OpenVAS = 18GB.
- **Attack sessions:** add Kali (4GB) and only the receivers required by the test.

Both SIEMs are installed, but are not permanently powered on. Adding ELK to a SOAR session reaches 28GB before host memory use, so this is not the routine operating set.

### 1.4 Success Criteria (what "done" looks like)

- [ ] Kali can attack a victim VM and Wazuh shows an alert
- [ ] IDS logs network-level attack traffic
- [x] Both SIEMs ingest logs from Wazuh, pfSense, and the IDS
- [x] OpenVAS produces a victim scan report (limited unauthenticated coverage; see validation record)
- [x] SOAR executes a controlled marker-file response; a separate manual workflow reverses it. Account disabling and IP blocking remain future exercises.

### 1.5 ISO & Software Checklist

Download and stage these before Phase 3 begins — having everything ready up front avoids stalling mid-build waiting on downloads. All are free for lab/personal use.

**Core infrastructure**

- [ ] **pfSense CE** — ISO from the official pfSense site (netgate.com/pfsense)
- [ ] **VMware Workstation Pro** — already installed (confirmed on your host)

**Operating systems (victims / directory)**

- [ ] **Windows Server** (2019/2022) ISO — Microsoft Evaluation Center (free 180-day trial ISO)
- [ ] **Windows 10 or 11** ISO — Microsoft Evaluation Center or standard consumer ISO you're licensed for
- [ ] **Kali Linux** ISO/VMware image — official Kali downloads page (VMware pre-built image saves setup time)

**Detection & monitoring**

- [ ] **Wazuh** — install script for Ubuntu Server ISO (Ubuntu Server 24.04 LTS as the base OS). *Update: the official Wazuh OVA was tried first and abandoned after integration difficulties — see [Configure Log Forwarding](configure-log-forwarding.md) for why. A from-scratch install on the same Ubuntu base as every other VM turned out to be the more reliable path.*
- [ ] **Suricata** — installed as a pfSense package (via pfSense's package manager, no separate ISO) *or* Ubuntu Server ISO if building it standalone
- [ ] **Ubuntu Server 24.04 LTS** ISO — base OS for Wazuh/Suricata/ELK/OpenVAS/SOAR if not using vendor-provided images/OVAs

**SIEMs**

- [ ] **Elastic Stack (ELK)** — Elasticsearch, Logstash, Kibana installers/packages from elastic.co (or Elastic's all-in-one installer), installed on Ubuntu Server
- [ ] **Elastic Agent / Beats** — for forwarding logs from Windows/Linux VMs to ELK
- [ ] **Splunk Enterprise** (free Developer license) — installer from splunk.com, requires free account signup
- [ ] **Splunk Universal Forwarder** — for forwarding logs from Windows/Linux VMs to Splunk

**Vulnerability management**

- [ ] **Greenbone Community Edition (OpenVAS)** — Docker Compose install (Docker Engine required on Ubuntu Server base) from greenbone.github.io

**SOAR**

- [ ] **Shuffle** (decided — see Step 3.9) — Docker Compose install from shuffler.io, installed on Ubuntu Server. *TheHive + Cortex was the alternative considered; Shuffle's drag-and-drop builder was chosen as the lighter starting point, given how much of this build's time has already gone to integration debugging.*

**Supporting tools**

- [ ] **Docker Engine** — needed for OpenVAS/Greenbone and for Shuffle; install via Ubuntu's package manager
- [ ] **Sysmon** — Microsoft Sysinternals, installed on Windows victim VMs for richer endpoint logging (feeds Wazuh/SIEM)
- [ ] **Windows Server ISO validation** — confirm the 180-day eval ISO's expiration date so you know when you'll need to re-arm or rebuild it

**Exit criteria for this checklist**

- [ ] All ISOs/installers downloaded and saved in one folder on the host
- [ ] Checksums verified where the vendor provides them (protects against a corrupted download causing a mysterious install failure later)
- [ ] Free accounts created where required (Splunk, Elastic if needed)

### Exit Criteria for Phase 1

- [ ] Component list finalized
- [ ] Hardware budget understood and accepted
- [ ] Pod strategy accepted
- [ ] Success criteria written down

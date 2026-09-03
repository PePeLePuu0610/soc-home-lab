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
| SOAR (Shuffle or TheHive + Cortex) | Security Orchestration, Automation and Response — automates your response steps | Response automation |
| Kali Linux | Attacker machine used to generate real traffic/attacks to detect | Attack simulation |
| Windows 10/11 + Windows Server (AD) | "Victim" machines representing a real corporate network | Target environment |
| Management Endpoint (KDE Linux) | Analyst workstation living in the Management zone, added after initial planning | Analyst tooling |

### 1.3 Critical Constraint: Your Hardware Budget

This is the most important planning decision, so it gets its own table. Below is what each VM realistically needs, and what happens if you try to run them all simultaneously.

| VM | RAM (planned / **actual once built**) | vCPU | Disk |
|---|---|---|---|
| pfSense (Suricata runs as a package inside this VM, not separately) | 2 GB | 2 | 20 GB |
| Kali (attacker) | 4 GB / **2 GB actual** | 2 | 40 GB |
| Windows 10 (victim) | 4 GB | 2 | 60 GB |
| Windows Server 2019 + AD | 4 GB | 2 | 60 GB |
| ELK stack (single node) | 8 GB / **4 GB actual** | 2 / **4 actual** | 60 GB |
| Splunk Enterprise (single instance) | 6 GB | 2 | 60 GB |
| Wazuh manager | 4 GB | 2 | 40 GB |
| OpenVAS/Greenbone | 4 GB / **6 GB actual** | 2 | 40 GB |
| SOAR (not yet built — planned) | 4 GB | 2 | 40 GB |
| **Total, actual specs where built** | **~36 GB** | — | **~380 GB** |

**Reality:** even the improved ~36GB total is still tight against 32GB if every VM runs at once — running everything simultaneously will thrash the host (heavy swapping, VMs freezing). This is normal for a home SOC lab — even professional lab guides assume you toggle VMs on and off. The plan below solves this with a **"pod" power-on strategy** instead of buying more hardware:

- **Pod A – Coree Detection (always on while working):** pfSense, one victim VM, Wazuh → ~10–11 GB
- **Pod B – SIEM (swap in one at a time):** ELK (4GB actual) *or* Splunk (6GB), not both, unless testing log forwarding side-by-side
- **Pod C – Offense (on only during exercises):** Kali → 2 GB actual
- **Pod D – Vulnerability/Response (on only when actively using):** OpenVAS (6GB actual), SOAR (4GB planned) → 6–10 GB

This keeps your working set around 22–27 GB, leaving headroom for the Windows 11 host OS itself.

Disk: 440GB of VM disks will fit inside your ~517GB free, but only if you build most disks as **thin-provisioned** (VMware allocates space as it's actually used, not all upfront) — this is a setting you'll choose in Phase 3.

### 1.4 Success Criteria (what "done" looks like)

- [ ] Kali can attack a victim VM and Wazuh shows an alert
- [ ] IDS logs network-level attack traffic
- [ ] At least one SIEM ingests logs from Wazuh, pfSense, and the IDS
- [ ] OpenVAS produces a vulnerability report on a victim VM
- [ ] SOAR tool can execute at least one automated response action (e.g., disable a user, block an IP)

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

- [ ] **TheHive + Cortex** — installers/Docker images from thehive-project.org, installed on Ubuntu Server, *or*
- [ ] **Shuffle** — Docker Compose install from shuffler.io (simpler drag-and-drop alternative)

**Supporting tools**

- [ ] **Docker Engine** — needed for OpenVAS/Greenbone and optionally TheHive/Shuffle; install via Ubuntu's package manager
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

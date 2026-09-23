## PHASE 3 — Implementation (Build)

**Goal:** Build the lab in a strict order — network first, then infrastructure, then detection tools, then the attacker.

Build one item at a time. Fully finish and confirm each step works before starting the next — this is the core discipline of Waterfall.

### Step 3.1 — Prep VMware Workstation

1. Open VMware Workstation Pro → **Edit → Virtual Network Editor**.
2. Create/confirm 3 Host-only networks (VMnet1, 2, 3) matching the subnets in 2.2. Untick "Use local DHCP service" for each — pfSense will hand out addresses instead, just like a real firewall.
3. Leave VMnet8 (NAT) as-is for pfSense's WAN.

### Step 3.2 — pfSense (build this first — everything else depends on it)

1. Download pfSense CE ISO (free) from the official pfSense site.
2. Create VM: 2GB RAM, 2 vCPU, 80GB thin-provisioned disk, 4 network adapters (WAN=NAT, LAN1=Mgmt, LAN2=Corp, LAN3=Attacker).
3. Install pfSense, assign interfaces to match Section 2.1.
4. From a browser on the host, log into pfSense's web interface and set up firewall rules: allow Management zone to reach everything (you need visibility everywhere); restrict Attacker zone to only reach Corp zone (simulates an external attacker reaching internal systems, not admin tools).
5. **Confirm:** ping between zones behaves as designed before moving on.

**5a. Confirm outbound internet access (needed for Windows Updates, `apt update`, tool downloads on every VM):**

   - Host-only networks are *not* internet-isolated by default — pfSense routes and NATs each LAN's traffic out through its WAN interface (which rides VMware's NAT network, VMnet8, out to your host's real connection) the same way a real office's internal network reaches the internet only through its edge firewall.
   - Check **Firewall → NAT → Outbound** is set to "Automatic" — this makes pfSense NAT traffic from all three Host-only subnets out to WAN with no extra config.
   - Set each VM's DNS server to its pfSense LAN IP (10.10.10.5 / 10.10.20.5 / 10.10.30.5), and confirm pfSense's DNS Resolver is enabled (**Services → DNS Resolver**) — default install has this on, but confirm it. No working DNS means updates will silently fail even with a good route.
   - **Temporarily allow outbound traffic while building/patching:** while you're actively installing OS updates or tools on a new VM, add a permissive "allow any outbound" rule on that VM's zone so nothing blocks the install. Remove or tighten it once the VM is fully built and patched — see the hardening step in Phase 5.
   - **Confirm:** from each VM, browse a website or run a package update and verify it completes successfully before moving to the next VM build.

### Step 3.3 — Corporate LAN victims

1. Build Windows Server VM (4GB/2vCPU/60GB), install, promote to a Domain Controller (this makes it the "brain" of a mini corporate network with user accounts — a standard SOC training setup).
2. Build Windows 10/11 victim VM (4GB/2vCPU/60GB), join it to the domain.
3. Assign static IPs per Section 2.2.

### Step 3.4 — Wazuh (HIDS/XDR)

1. Build a Wazuh manager VM on Ubuntu 24.04 (6GB/4vCPU/100GB), using Wazuh's official install script. **Decision made:** the official Wazuh OVA was tried first and abandoned after integration difficulties (different base OS from the rest of the lab caused several build steps to assume the wrong package manager, and its bundled Filebeat conflicted with the log-forwarding setup) — see [Configure Log Forwarding](configure-log-forwarding.md) for the full story. Building from scratch on the same Ubuntu base as everything else removed that whole class of problem.
2. Install the Wazuh agent on the Windows victim VM and point it at the manager.
3. **Confirm:** Wazuh dashboard shows the Windows agent as "active."

### Step 3.5 — IDS (Suricata)

**Decision made:** installed as a pfSense package rather than a standalone VM, for simplicity — one less VM to build, patch, and keep running.

1. ~~Enable Suricata as a pfSense package~~ **Done.**
2. Point it at the Corp-zone interface so it inspects traffic to/from your victim machines.

### Step 3.6 — SIEM #1: ELK Stack

**Full step-by-step build guide: [Build Guide: ELK Stack VM](build-elk-stack.md)**

1. Build ELK VM on Ubuntu 24.04 (**actual: 8GB RAM / 4 vCPU / 100GB disk**), static IP `10.10.10.10`.
2. Install Elasticsearch, Kibana, and Logstash.
3. **Configure Logstash/Beats to receive logs from Wazuh, pfSense, Suricata, OpenVAS, and Windows — see [ELK Ingestion Plan](elk-ingestion-plan.md)** for objectives/sequencing/exit gates, or jump straight to [Configure Log Forwarding](configure-log-forwarding.md) for the commands. Deliberately split out as its own step: it touches five separate VMs, not just this one, and is easy to defer until both SIEMs and OpenVAS exist and you can wire up everything at once.
4. **Confirm:** logs appear in Kibana within a few minutes of test traffic.

### Step 3.7 — SIEM #2: Splunk Enterprise

**Full step-by-step build guide: [Build Guide: Splunk Enterprise VM](build-splunk-enterprise.md)**

1. Build Splunk VM (6GB/2vCPU/100GB), static IP `10.10.10.14`.
2. Install Splunk Enterprise via the free trial license (fine for a lab, not for production).
3. **Configure the same log sources as ELK — see [Configure Log Forwarding](configure-log-forwarding.md)**, so you can compare how each SIEM presents the same data — this is a genuinely useful comparison exercise for interviews.
4. **RAM note:** Pod A is 12GB; adding ELK and Splunk totals 26GB. Power receivers on as needed and leave Shuffle/OpenVAS off for dual-SIEM sessions.

### Step 3.8 — OpenVAS (Vulnerability Management)

**Full step-by-step build guide: [Build Guide: OpenVAS (Greenbone Community Edition)](build-openvas.md)**

1. Build OpenVAS/Greenbone VM on Ubuntu 24.04 (**actual: 6GB RAM** / 2vCPU / 100GB), static IP `10.10.10.12` — Docker-based install, using Greenbone's official Community Edition container stack.
2. Point a scan at the Windows victim VM's IP.
3. **Confirm:** a vulnerability report generates.
4. **RAM note:** this is the tightest fit yet with two SIEMs already running — see the guide's "Before you start" section.

### Step 3.9 — SOAR

**Status: complete for the agreed controlled response and manual reversal scope, September 22, 2026.**

As-built record: [Shuffle Deployment and Response Validation](build-shuffle.md).

1. Deployed Shuffle on `soc-soar-shfl`, `10.10.10.13`, Ubuntu 24.04.5 LTS, 8GB RAM / 4 vCPU / approximately 100GB disk.
2. Verified Docker, Compose, admin login, workflow execution, and a successful workflow run after reboot.
3. Configured Wazuh's native Shuffle integration for JSON alerts at level 7 or higher; retained both syslog outputs and Indexer.
4. Validated Windows rule `60602` (level 9), matching payload IDs across Wazuh and Shuffle.
5. Tested positive and negative marker conditions between app actions.
6. Created API account `shuffle_lab`, linked to role `shuffle_lab_operator` and policy `shuffle_lab_response`, scoped to agent `001`.
7. Automatically created a marker file via the Wazuh API and confirmed its contents on Windows.
8. Removed that marker via a separate manual Shuffle reversal workflow and confirmed `Test-Path` returned `False`.

TheHive/Cortex remain deferred. This is a marker-file demonstration, not host isolation, AD account disabling, or completion of Phase 4's attack tests.

### Step 3.10 — Kali (Attacker)

1. Kali is built (4GB/4vCPU/40GB); keep it on the Attacker Zone network only.
2. Power it on only for the selected attack exercise after checking the network rules.

### Exit Criteria for Phase 3

- [ ] Every VM listed above is built and powered on successfully at least once
- [ ] pfSense routes and filters traffic between all zones as designed
- [x] Wazuh shows an active agent
- [x] At least one SIEM is receiving logs
- [x] OpenVAS has completed one scan
- [x] SOAR has one working playbook

Phase 3 has not been blanket-signed off: confirm the inventory-wide power-on checklist and network filtering separately. Step 3.9 does not close the Phase 4 attack matrix.

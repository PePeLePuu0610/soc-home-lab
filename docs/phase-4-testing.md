## PHASE 4 — Testing & Verification

**Goal:** Prove the lab actually detects and responds to attacks, end-to-end.

| Test | Steps | Pass condition |
|---|---|---|
| Network isolation | From Kali, try to reach the Management zone directly | Blocked by pfSense |
| Attack detection (network) | Run an Nmap scan from Kali against the Windows victim | Suricata logs the scan |
| Attack detection (host) | Run a brute-force login attempt against the Windows victim | Wazuh raises an alert |
| SIEM ingestion | Check Kibana/Splunk during the above tests | Wazuh + Suricata events visible within minutes |
| Vulnerability scan | Run OpenVAS against the victim | Report lists real findings (e.g., missing patches) |
| SOAR response | Trigger the alert type your playbook watches for | Playbook fires and completes its action automatically |
| Full chain | Repeat the brute-force test start to finish | You can trace: attack → IDS/HIDS alert → SIEM dashboard → SOAR action, without manual steps in between |

### Exit Criteria for Phase 4
- [ ] All 7 tests above pass
- [ ] Any failures documented with root cause (e.g., "logs weren't reaching Splunk because the forwarder wasn't installed")

# Firewall policy and alias record

Retrospective record through October 8, 2026, assembled from session evidence. This is a documented configuration summary, not a fresh live export or a complete ordered ruleset. Rule order and exact UI names must be reconciled against a private pfSense configuration export before restore or automation.

## Network and gateway
| Interface | Zone | Address / attachment |
| --- | --- | --- |
| em0 | WAN | 10.10.40.5; VMware VMnet8; gateway 10.10.40.2 |
| em1 | Management | 10.10.10.5/24; VMnet1 |
| em2 | Corporate | 10.10.20.5/24; VMnet2 |
| em3 | Attacker | 10.10.30.5/24; VMnet3 |

Host management address 10.10.10.1; host WAN-side adapter 10.10.40.1. Persistent route to corporate subnet uses 10.10.10.5. Host adapters for VMnet2/3 were disabled; virtual switches remain in use.

## Alias membership
Labels below normalize the session names; verify exact saved spelling in pfSense before scripting.

| Alias purpose | Membership |
| --- | --- |
| ADMIN_HOSTS | 10.10.40.1 |
| Management administrator | 10.10.10.1 |
| MGMT_NET | 10.10.10.0/24 |
| CORP_NET | 10.10.20.0/24 |
| ATTACK_NET | 10.10.30.0/24 |
| PRIVATE_NETS | 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 |
| CORP_ENDPOINT_HOSTS / CORP_SCAN_TARGETS | 10.10.20.10, 10.10.20.20 |
| ELK / WAZUH / OPENVAS / SHUFFLE / SPLUNK hosts | 10.10.10.10 / .11 / .12 / .13 / .14 |
| Web update ports | TCP 80,443 |
| Windows administration ports | TCP 3389,5985,5986 |
| Wazuh enrollment | TCP 1515; rule disabled |
| Splunk management / Winlogbeat | TCP 8089 / 5044; Winlogbeat rule disabled |

Oversized host aliases were corrected to the intended individual addresses. Old broad management/corporate rules and the floating allow-all rule were disabled.

## Recorded policy
| Zone | Action / source → destination | Ports | Tracker where recorded |
| --- | --- | --- | --- |
| WAN | Pass ADMIN_HOSTS → WAN address | TCP 443 | 1791038543 |
| Management | Pass approved management administrator → corporate targets | TCP 3389,5985,5986 | 1791410919 |
| Management | Pass OpenVAS 10.10.10.12 → corporate targets | IPv4 any | 1791410049 |
| Management | Pass management → interface services | DNS TCP/UDP 53; NTP UDP 123; approved GUI TCP443 | Not fully preserved |
| Management | Block This Firewall, then private destinations outside exceptions | As recorded in UI | 1791410170 / 1791410393 |
| Management | Pass Internet web updates | TCP 80,443 | 1791410490 |
| Corporate | Pass endpoint alias → Wazuh 10.10.10.11 | TCP 1514 | 1791029247 |
| Corporate | Pass approved Splunk forwarding/management | TCP 9997,8089 | Rule retained; service paused |
| Corporate | Pass DC → corporate interface DNS; endpoints → NTP | DNS TCP/UDP53; NTP UDP123 | Not fully preserved |
| Corporate | Block This Firewall, private destinations outside exceptions | As recorded in UI | 1791034127 / 1791034210 |
| Corporate | Pass Internet web updates, final block | TCP80,443 / remaining traffic | Final block 1791033701 |
| Attacker | Pass interface DNS/NTP; block corporate, firewall and other private destinations | DNS/NTP exceptions; other traffic blocked | Corporate 1791037061; private 1791037200 |
| Attacker | Pass Internet web updates, final block | TCP80,443 / remaining traffic | Web pass 1791037303 |

Management anti-lockout was retained. Same-subnet management traffic is not governed by routed firewall rules. Full IPv6 review remains open.

## Historical validation and limits
- Approved host RDP passed; ELK-to-victim RDP was blocked.
- OpenVAS connections to DC were logged as passed under tracker 1791410049.
- Endpoint Wazuh forwarding passed; enrollment rule stayed disabled.
- Victim → firewall GUI and ELK5601 were blocked.
- Kali probes against corporate victim, ELK and WAN-side host on TCP443/445/5601 returned filtered, with nine corresponding firewall blocks. Scanner output alone was not the proof.
- DNS and web updates passed for tested paths.
- Targeted old states were cleared after policy/alias changes. Old ACK blocks were not treated as proof that new allowed sessions failed.

These checks preceded the post-reboot regression validation unless explicitly documented otherwise. Do not call the full policy revalidated after recovery.

## Recovery and evidence
Local unencrypted pfSense XML backup includes extra data and SSH keys; retain privately. openvas-dc-filterlog.txt and session screenshots support selected rules and tests. No raw configuration backup is copied into this repository. Syslog startup recurrence and post-reboot ingestion remain open.


# SOC-001 command and evidence log — October 21, 2026

This is the detailed companion to [today's activity log](soc-001-activities-2026-10-21.md). Commands below were supplied during this session; outcomes distinguish observed output from steps whose exact execution output was not supplied. Run commands individually unless a shell block is explicitly intended. Passwords are entered only at prompts. No live command is executed by reading this record.

## 1. Restart and pfSense-to-ELK troubleshooting

| Where | Command / query | Why | Observed outcome |
|---|---|---|---|
| pfSense | `logger -t SOC-VALIDATION "SOC001-RESTART-20261021-01"` | Generate unique benign system event | Local log shows 06:08:24; initially absent from ELK |
| pfSense | Same command with suffix `-02` | Repeat local event test | Local log shows 06:16:19; initially absent from ELK |
| pfSense | `grep -F 'SOC001-RESTART-20261021' /var/log/system.log` | Verify source event generation | Both early markers present; source logging initially worked |
| Both hosts | `date` | Inspect clock/timezone context | Both displayed MDT; captures at different times do not establish drift |
| ELK | `sudo systemctl status logstash --no-pager -l` | Confirm receiver process available | Active/running, PID 1283 |
| ELK | `sudo ss -lunp 'sport = :5514'` | Check UDP listener | Java PID 1283 listening on 0.0.0.0:5514 |
| ELK | `sudo timeout 30 tcpdump -ni any -nn -A -c 5 'udp dst port 5514 and src host 10.10.10.5'` | Observe incoming pfSense syslog | Zero captured packets |
| ELK | `sudo timeout 30 tcpdump -ni any -nn -A -c 10 'udp dst port 5514'` | Remove source-address assumption | Zero captured packets |
| pfSense | `grep -Rn '@' /var/etc/syslog.d` | Check generated remote destinations | ELK 10.10.10.10:5514 configured; no new destination change made |
| pfSense | `route -n get 10.10.10.10` | Identify outbound interface | Direct management network via em1 |
| pfSense | `tcpdump -ni em1 -nn -A -c 5 'udp and dst host 10.10.10.10 and dst port 5514'` | Check transmission from firewall | Zero captured; stopped with Ctrl+C. Filter receive counter does not prove forwarded syslog |
| pfSense | `grep -F 'SOC001-RESTART-20261021-05' /var/log/system.log` | Verify latest marker locally | No match |
| pfSense | `pgrep -laf syslogd` | Check actual daemon processes | No output at failure; GUI subsequently red |
| pfSense | `tail -n 30 /var/log/system.log` | Inspect recent activity | Displayed records stopped around 06:17:20 |
| pfSense GUI | Start syslogd from Services | Recover stopped logger | Joey restarted; green afterward. Root cause remains open |
| pfSense | `logger -t SOC-VALIDATION "SOC001-RESTART-20261021-06"` | Validate recovery with fresh marker | Reached ELK at displayed 06:40:41.315 |
| Kibana pfsense view | `message: "SOC001-RESTART-20261021-06"` | Match recovery marker | One document, host.ip 10.10.10.5 |
| Kibana Wazuh Alerts view | `agent.id: "001" OR agent.id: "002"` | Verify endpoint forwarding to separate ELK | Export 984 rows, victim 694/DC 290; latest displayed 06:44:04/06:44:15 |

Markers -03 through -05 were also proposed during capture tests; exact local records were not supplied for each. Avoid inferring that every proposed marker was generated during its capture window. Initially two commands pasted together made grep interpret `date` as a filename; corrected by executing them separately.

Gateway inspection: WAN Static IPv4 10.10.40.5/24, default WAN_STATIC 10.10.40.2; duplicate WAN_DHCP used same gateway and monitor. No gateway deletion/change was made. The directly connected ELK route does not use WAN.

## 2. Victim WMI readiness and applied firewall change

| Where | Command | Why / result |
|---|---|---|
| Victim administrator PowerShell | `Get-Service Winmgmt, RemoteRegistry | Select-Object Name, Status, StartType` | Supplied individual outputs: Winmgmt Running/Automatic, RemoteRegistry Running/Manual |
| Victim | `Start-Service -Name RemoteRegistry` | Start manual service for authenticated checks; Running confirmed |
| Victim | `Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber` | Local CIM/WMI health: Windows 10 Pro for Workstations 10.0.19045 / 19045 |
| Victim | `Get-NetConnectionProfile | Select-Object InterfaceAlias, NetworkCategory` | Ethernet0 DomainAuthenticated |
| OpenVAS host | `nc -vz -w 3 10.10.20.20 135` | RPC endpoint mapper TCP reachable; not proof of WMI or dynamic RPC access |
| Victim | `Get-NetFirewallRule -PolicyStore ActiveStore -Name 'WMI*' | Select-Object Name, Enabled, Profile, Direction, Action` | All inspected built-in WMI rules disabled |
| Victim | `Get-NetFirewallRule -PolicyStore ActiveStore -Name 'WMI*' | Get-NetFirewallAddressFilter | Select-Object InstanceID, RemoteAddress` | Domain variants Any; other profile variants LocalSubnet; disabled rules do not permit traffic |

Applied scoped change (confirmed enabled; Joey approved retaining it):

```powershell
New-NetFirewallRule -Name 'SOC-OpenVAS-WMI-In' -DisplayName 'SOC OpenVAS WMI inbound' -Direction Inbound -Action Allow -Protocol TCP -Program "$env:SystemRoot\System32\svchost.exe" -Service Winmgmt -RemoteAddress 10.10.10.12 -Profile Domain
Get-NetFirewallRule -Name 'SOC-OpenVAS-WMI-In' | Select-Object Name, Enabled, Profile, Direction, Action
```

Why: allow scanner-only inbound WMI service traffic on the authenticated Domain profile. The local persistent rule survives normal reboots; effective policy still requires verification. Defender and DCOM hardening remain enabled.

Rollback **documented, not executed**:

```powershell
Disable-NetFirewallRule -Name 'SOC-OpenVAS-WMI-In'
```

See [endpoint build guide](build-windows-endpoint-scan-readiness.md#october-21-accepted-wmi-baseline) for pre-scan checks and re-enable procedure.

## 3. Scanner clients and DCOM diagnosis

All container commands use `sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml`. `exec ospd-openvas` opens a process in the existing scanner container. Omit `-T` for a password-prompting interactive test; use `exec -T` for noninteractive output.

| Command after Compose prefix | Why | Outcome |
|---|---|---|
| `exec -T ospd-openvas sh -c 'command -v wmic; command -v impacket-wmiquery; command -v wmiquery.py'` | Locate existing tools without installation | /usr/local/bin/wmic and /usr/local/bin/wmiquery.py found; host equivalents absent |
| `exec -T ospd-openvas /usr/local/bin/wmiquery.py -h` | Read actual syntax | Impacket 0.13.1 help supplied |
| `exec ospd-openvas /usr/local/bin/wmiquery.py 'SOCHOMELAB/secadmin@10.10.20.20'` | Read-only remote WMI through Impacket | Password prompt, WQL shell; query below returned build 19045; exit with `exit` |
| `exec -T ospd-openvas find /var/lib/openvas/plugins -type f -name 'gb_wmi_access.nasl' -exec sed -n '1,220p' {} \;` | Inspect installed producer of WMI status key | OID 108205 sets flag only after native wmi_connect succeeds |
| `exec -T ospd-openvas sh -c 'grep -iE "nasl_wmi_connect|WMI Connect|wmi_connect" /var/log/openvas/openvas.log | tail -n 30'` | Correlate scanner failures | Native failure at 13:53:04 UTC during retest; later 16:46:44 report unreviewed |
| `exec -T ospd-openvas /usr/local/bin/wmic --help` | Inspect native client options | Password prompt supported; avoid passwords in arguments |
| `exec ospd-openvas /usr/local/bin/wmic -U 'SOCHOMELAB/secadmin' //10.10.20.20 'SELECT Caption, Version, BuildNumber FROM Win32_OperatingSystem'` | Test native WMI independently | Access denied; repeated |
| Same native command with `--option='client signing=required'` | Diagnostic attempt at signing | Same error; not a DCOM activation fix. Do not treat as operating workaround |
| `images` | Inventory deployed images without pulling | Scanner f045254d796b; ospd-openvas db44c0dbdc63 in supplied inventory |
| `exec -T ospd-openvas /usr/local/bin/wmic --version` | Inspect native banner | 4.0.0tp4-SVN-build-UNKNOWN; not reliable packaged release identification |
| `exec -T ospd-openvas sh -c 'openvas --version; dpkg-query -W "*openvas*" "*smb*" 2>/dev/null'` | Inspect scanner/package provenance | OpenVAS 23.50.20 / gvm-libs 23.9.2; no package rows |

Impacket WQL query:

```sql
SELECT Caption, Version, BuildNumber FROM Win32_OperatingSystem
```

Victim event check (read-only):

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-DistributedCOM'
    Id = 10036
    StartTime = (Get-Date).AddMinutes(-15)
} -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, Message |
    Format-List
```

Result: two displayed 12:08 events named scanner 10.10.10.12/domain account and required RPC_C_AUTHN_LEVEL_PKT_INTEGRITY. Evidence supports native-client activation authentication mismatch, not blanket lack of account permission.

**Successful explicit native binding test:**

```sh
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml exec ospd-openvas /usr/local/bin/wmic -U 'SOCHOMELAB/secadmin' '//10.10.20.20[sign,seal]' 'SELECT Caption, Version, BuildNumber FROM Win32_OperatingSystem'
```

Result supplied as text: Windows 10 Pro for Workstations / 19045 / 10.0.19045. This alters only this connection. Saved Greenbone behavior remains unresolved. No vendor NASL file was edited and no Windows security feature was weakened.

## 4. Targeted Greenbone retest and export controls

GUI procedure: clone Base, retain its three tests, add Windows 96199 (WMI file shares), 108539 (SMB success), 108442 (LSC consolidation). Name SOC-001 — Victim SMB-WMI validation. Verify auto_enable_dependencies=Yes and safe_checks=Yes. Use new victim-only task with existing Domain Credentials; no schedule. Six explicitly selected NVTs can run additional dependencies.

Report export filter: `min_qod=0 levels=chmlg rows=1000 apply_overrides=0`. CSV/XML matched 14 IDs. SMB/registry passed and WMI file shares returned ADMIN$, C$, IPC$; consolidation remained FALSE. A Notus error was embedded in a Log result although the XML error list was empty. This targeted scan is not a vulnerability-clearance scan.

## 5. OpenVAS host patching and feed maintenance

| Where / command | Why | Outcome / caution |
|---|---|---|
| OpenVAS `apt list --upgradable` | Inventory pending packages | Included Docker/containerd/Compose/Filebeat and Ubuntu components |
| Compose prefix + `stop` | Graceful stack stop before snapshot/host work | Instructed before powered-off snapshot; exact stop output not retained |
| `sudo shutdown -h now` | Clean VM shutdown | Operator confirmed snapshot complete afterward |
| VMware snapshot | Recovery point before upgrades | SOC-001 — Pre-OpenVAS host updates — 2026-10-21, completion reported, metadata not independently read |
| `sudo apt update` | Refresh package metadata, not install | Instructed before supplied simulation |
| `sudo apt-get -s upgrade` | Preview transaction without installing | 61 upgrades, zero new/removals, seven phased packages deferred |
| `sudo apt-get upgrade` | Install reviewed host upgrades | Installation log supplied; Docker, containerd, Compose and Filebeat configured |
| `sudo dpkg --audit` | Detect incomplete package configuration | Clear output |
| `sudo apt-get check` | Verify dependencies | No error in supplied output |
| `if [ -f /var/run/reboot-required ]; then cat /var/run/reboot-required; else echo "No reboot-required flag"; fi` | Check restart requirement | System restart required |
| `sudo reboot` | Complete maintenance restart | Post-reboot checks supplied |
| `systemctl is-active docker containerd` | Verify runtime services | Both active |
| Compose prefix + `ps -a` | Inspect containers and historical exits | gvmd/pg-gvm healthy, main runtime services up. Historical exit 137 is not proof of current OOM |

SSSD AppArmor complain-mode warning in installation log remains a separate follow-up, not a fatal package error. No autoremove, volume deletion or full stack image upgrade was authorized by this procedure.

Exact feed-only pull/up commands and log checks, with explanation and acceptance gates, are in [maintenance procedure](phase-6-maintenance.md#openvas-feed-only-maintenance). All four categories subsequently Current; existing reports/custom config accessible. Host updates and feed downloads are separate operations.

## 6. Evidence locator

Raw evidence is not uploaded to public Git. Selected screenshots are archived outside the repository under `E:\PePesLab-SOC 2.0\Evidence\SOC-001\2026-10-21`. Filenames below refer to that private archive; the manifest there preserves original paths and SHA256 values. This register indexes only relevant examples, not every screenshot from the conversation. Text-only successful tests are labeled as such above.

| Private screenshot | What it supports |
|---|---|
| `01-syslog-process-absent.png` | No syslogd process at failure |
| `02-syslog-recovery-marker.png` | Fresh marker -06 arrived in ELK |
| `03-victim-local-wmi-domain.png` | Local CIM and DomainAuthenticated profile |
| `04-wmi-rule-applied.png` | Dedicated WMI rule created/enabled |
| `05-impacket-wmi-success.png` | Remote WQL OS query passed |
| `06-native-wmic-denied.png` | Native client access denied |
| `07-dcom-10036.png` | Activation integrity rejection; contains account SID, retain privately |
| `08-package-audit-reboot.png` | Clear package audit/dependencies, reboot required |
| `09-docker-active.png` | Docker/containerd active after reboot |
| `10-feeds-current.png` | All four feed categories Current |

Other originals: complete October 9 report exports with suffix (2), October 21 WMI retest CSV/XML, ELK Untitled Discover session (5).csv, and openvas-update-log.txt remain in Downloads. Activity log records report hashes. No password or raw credential file belongs in this register.

## References

- [Microsoft remote WMI setup](https://learn.microsoft.com/en-us/windows/win32/wmisdk/connecting-to-wmi-remotely-starting-with-vista)
- [Greenbone scanner WMI binding implementation](https://github.com/greenbone/openvas-scanner/blob/v23.50.20/nasl/nasl_wmi.c)
- [Greenbone feed workflow](https://greenbone.github.io/docs/latest/22.4/container/workflows.html#performing-a-feed-synchronization)

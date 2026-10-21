# Build guide — Windows endpoint authenticated-scan readiness

Applies to approved corporate Windows endpoints. Recorded change October 8, 2026 on soc-victim-win10 (10.10.20.20); OpenVAS source 10.10.10.12. Owner Joey. TCP connectivity, direct SMB authentication and ADMIN$ read access verified; scanner-based authenticated coverage remains pending.

## Observed problem and change
- OpenVAS TCP445 connection timed out although the victim's SMB listener and LanmanServer were running.
- pfSense logged a passed initial SYN under tracker1791410049. This alone did not prove a handshake.
- Victim profile was Private; inspected built-in SMB inbound rules were disabled.
- RemoteRegistry was Disabled and could not start.
- Changed RemoteRegistry to Manual and started it; screenshot shows Running.
- Created local persistent rule SOC-OpenVAS-SMB-In: inbound Allow, TCP445, source10.10.10.12 only, Private and Domain profiles. Public profile excluded.
- After the new rule, OpenVAS nc connection to10.10.20.20:445 succeeded. This verifies the tested TCP path, not credential success, registry access or WMI authorization.

Evidence: user-supplied rule creation screenshot codex-clipboard-dbf73125-3bf2-416a-9026-d1363ac0fa96.png and successful connection screenshot codex-clipboard-ba0e506d-8784-4fe0-8b79-436605aa6e90.png, retained privately. Precise capture time not established.

## Future endpoint prerequisites
1. Assign an approved unique IP, hostname and corporate virtual network. Review capacity before adding another VM.
2. Configure domain DNS and join the intended domain; validate DNS/domain connectivity. Do not force a DomainAuthenticated profile manually. The current victim's Private profile remains an investigation item.
3. Install/configure Wazuh and verify a new agent's own ID and recent events.
4. Confirm the scan account's intended remote privileges without assuming interactive logon proves SMB access; never place passwords in Git or command arguments.
5. Explicitly approve any new scan target and update both pfSense corporate endpoint/scan aliases and the OpenVAS target. Do not widen target subnets automatically. Existing approved scan targets remain .20.10 and .20.20.
6. Record original service start mode/status and existing firewall rules before changes. Keep Windows Firewall and Defender enabled.

## Read-only baseline (elevated PowerShell)
```powershell
whoami
Get-Service -Name LanmanServer, Winmgmt, RemoteRegistry, WazuhSvc |
    Select-Object Name, Status, StartType
Get-NetConnectionProfile |
    Select-Object InterfaceAlias, NetworkCategory
Get-NetTCPConnection -State Listen -LocalPort 445 -ErrorAction SilentlyContinue
Get-NetFirewallRule -Name 'SOC-OpenVAS-SMB-In' -ErrorAction SilentlyContinue
```
If the custom rule already exists, inspect it and its address/port filters rather than creating a duplicate. A local firewall rule may be constrained by domain policy or explicit block rules.

## Configure RemoteRegistry when authenticated checks require it
Recorded on this victim:
```powershell
Set-Service -Name RemoteRegistry -StartupType Manual
Start-Service -Name RemoteRegistry
Get-Service -Name RemoteRegistry |
    Select-Object Name, Status, StartType
```
Manual startup does not promise the service will run after every reboot. Check it during scan preparation; do not change to Automatic without a separate operational decision.

## Add scanner-only SMB exception
Recorded command (run once when rule does not already exist):
```powershell
New-NetFirewallRule -Name 'SOC-OpenVAS-SMB-In' -DisplayName 'SOC OpenVAS SMB inbound' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -RemoteAddress 10.10.10.12 -Profile Private,Domain
```
This preserves the existing built-in rule states. It does not open SMB to all management hosts or the Public profile.

Verification (recommended checks):
```powershell
Get-NetFirewallRule -PolicyStore ActiveStore -Name 'SOC-OpenVAS-SMB-In' |
    Select-Object Name, Enabled, Profile, Direction, Action
Get-NetFirewallRule -PolicyStore ActiveStore -Name 'SOC-OpenVAS-SMB-In' |
    Get-NetFirewallAddressFilter | Select-Object RemoteAddress
Get-NetFirewallRule -PolicyStore ActiveStore -Name 'SOC-OpenVAS-SMB-In' |
    Get-NetFirewallPortFilter | Select-Object Protocol, LocalPort
```

## Connectivity and authentication acceptance
From OpenVAS, substituting only an approved endpoint IP:
```bash
nc -vz -w 3 10.10.20.20 445
```
Recorded result for current victim: succeeded. If timeout persists, correlate current pfSense logs, active endpoint rules and return routing. Do not disable either firewall to troubleshoot.

### Direct SMB authentication — verified after the change

The OpenVAS host and gvm-tools container initially returned no smbclient path. Installing the host diagnostic client was instructed; subsequent successful execution establishes client availability. Package install output/version was not supplied. Record diagnostic tooling in future scanner builds when this validation method is selected.

```bash
smbclient '//10.10.20.20/ADMIN$' -U 'SOCHOMELAB\secadmin' -c 'ls'
```

Password entered at the prompt. Supplied screenshot codex-clipboard-be07ce0f-0293-44dd-8110-bb4c6ccaccb7.png shows a Windows directory listing from ADMIN$. Result: direct remote SMB login and share read access passed. This does not prove the password saved in Greenbone is identical, nor validate remote registry/WMI execution or scanner LSC completeness. Exact capture time is unavailable; file modification timestamps in the listing are not test timestamps.

October 8 status was pending scanner verification; the October 21 evidence and applied WMI change below supersede that status.

| Acceptance item | Current victim result |
| --- | --- |
| Domain account interactive login | Verified |
| SMB service and listener | Verified |
| RemoteRegistry Running / Manual | Verified after change |
| Scanner-only firewall rule created | Verified |
| OpenVAS → victim TCP445 | Verified after change |
| Remote SMB credential success | Verified via password-prompting smbclient; ADMIN$ listing succeeded |
| Registry and WMI authenticated coverage | SMB login and registry passed. October 21 targeted Greenbone WMI share enumeration passed, but consolidation remains FALSE. Direct Impacket and explicit native sign/seal queries passed; full scanner coverage remains open |
| Domain network classification | DomainAuthenticated observed October 21; earlier Private observation retained as history |
| Rollback executed | Not tested |

## Rollback
Disable the newly added rule; do not delete it:
```powershell
Disable-NetFirewallRule -Name 'SOC-OpenVAS-SMB-In'
```
Restore this victim's recorded original RemoteRegistry state (Disabled / Stopped), after deciding scan preparation is no longer needed:
```powershell
Stop-Service -Name RemoteRegistry
Set-Service -Name RemoteRegistry -StartupType Disabled
```
For future endpoints restore their recorded baseline, not this victim's setting by assumption. If policy or prior configuration already supplied a rule, restore only the authorized changes.

Validate restored rule/service states and intended network restrictions. TCP timeout alone is not sufficient rollback evidence because other allow rules could exist. Rollback affects authenticated-scan access; no rollback has been executed in this record.

## Maintenance

### October 21 accepted WMI baseline

Joey approved retaining `SOC-OpenVAS-WMI-In` enabled as the victim's scan-ready baseline. The local persistent firewall rule survives normal reboots; it does not need recreation or toggling for each scan. Group Policy or other configuration changes can affect effective enforcement, so verify the effective rule before scanning.

Applied on victim 10.10.20.20:

```powershell
New-NetFirewallRule -Name 'SOC-OpenVAS-WMI-In' -DisplayName 'SOC OpenVAS WMI inbound' -Direction Inbound -Action Allow -Protocol TCP -Program "$env:SystemRoot\System32\svchost.exe" -Service Winmgmt -RemoteAddress 10.10.10.12 -Profile Domain
```

Scope: inbound TCP for svchost.exe / Winmgmt, only from scanner 10.10.10.12, only on the Domain profile. Do not broaden to Any source or other profiles by default. Built-in WMI rules were observed disabled; local WMI and TCP 135 worked before this addition.

Validation: Impacket 0.13.1 wmiquery.py in ospd-openvas, using SOCHOMELAB/secadmin with a private password prompt, successfully executed `SELECT Caption, Version, BuildNumber FROM Win32_OperatingSystem`, returning Windows 10 Pro for Workstations / 10.0.19045 / 19045. This establishes this tool's remote WMI query, not a subsequent Greenbone WMI result.

Pre-scan: confirm DomainAuthenticated network classification, Winmgmt running (Automatic observed), RemoteRegistry running (Manual retained), effective WMI and SMB scanner rules enabled, and scanner address unchanged. Start RemoteRegistry if stopped; do not change its startup type by assumption. Keep Defender and Windows Firewall enabled.

Rollback, not executed:

```powershell
Disable-NetFirewallRule -Name 'SOC-OpenVAS-WMI-In'
```

Re-enable an intentionally disabled rule with `Enable-NetFirewallRule -Name 'SOC-OpenVAS-WMI-In'`; do not recreate it. For new Windows endpoints, record their own baseline and validate scope and domain dependencies before applying this pattern.

Review source-IP changes, new endpoint approvals, profile changes and firewall policy drift. Record each new endpoint's baseline, exact change, validation and rollback. Reconcile final authenticated report coverage before declaring the build scan-ready.

Sources: [Microsoft firewall rule reference](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule) and [Greenbone Windows authenticated scan requirements](https://docs.greenbone.net/GSM-Manual/gos-24.10/en/scanning.html).

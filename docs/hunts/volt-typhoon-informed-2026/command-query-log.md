# Command and query log

**TLP:CLEAR**

Case SOC-HUNT-2026-001 | September 24–October 3, 2026

This appendix documents the successful procedures, unsuccessful attempts, search logic, results and changes recorded in the investigation. Commands are grouped in execution phases, not presented as a timestamp-perfect shell transcript. **Captured** means the command or procedure is visible in supplied chat evidence; **reconstructed** means a repeatable equivalent assembled from the investigation context. Exact original syntax is unavailable for some initial checks and test markers; those are explicitly identified. Proposed commands are not executed evidence.

Use Windows commands on the victim, Linux commands on the indicated server, SPL in Splunk Web, and pfSense commands only in the appropriate Diagnostics command area. Windows system-changing commands require elevated PowerShell. Times in examples are fixed historical evidence windows; rolling searches executed later will cover different data.

## Phase 1 Endpoint audit baseline and enablement

### C01 Process audit baseline

Platform: victim. Status: reconstructed equivalent of initial check.

```powershell
Get-Service WazuhSvc
auditpol /get /subcategory:"Process Creation"
Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name ProcessCreationIncludeCmdLine_Enabled -ErrorAction SilentlyContinue
```

Result: WazuhSvc running; Process Creation No Auditing; command-line registry value absent. Absence of that registry property was not a malicious finding. Initial exact output is represented by the session account of the check rather than a standalone supplied text artifact.

### C02 Enable process auditing and command lines

Status: reconstructed from the recorded applied change.

```powershell
auditpol /set /subcategory:"Process Creation" /success:enable
$auditPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
New-Item -Path $auditPath -Force | Out-Null
New-ItemProperty -Path $auditPath -Name ProcessCreationIncludeCmdLine_Enabled -PropertyType DWord -Value 1 -Force | Out-Null
auditpol /get /subcategory:"Process Creation"
Get-ItemProperty -LiteralPath $auditPath -Name ProcessCreationIncludeCmdLine_Enabled
```

Result: Success and value 1 verified. Historical processes before enablement were not recovered. Subsequent direct 4688 events contained command lines.

### C03 Benign execution marker and local event review

Status: recorded marker; repeatable local query reconstructed.

```powershell
cmd.exe /c "echo SOC_VOLT_HUNT_VISIBILITY_TEST"
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688} -MaxEvents 20 |
    Format-List TimeCreated, RecordId, Message
```

Result: record 42962 at September 24 19:30:42, seclabadmin, logon ID 0x7a169, parent PowerShell. Wazuh rule 67027 level 3 at 19:30:45.988−0600. First Splunk marker unlocated. Later TEST_02 executions returned 43496 and 43497; the exact second marker command text was not preserved and is not invented here.

### C04 Wazuh and receiver checks

Status: exact filtering procedure reconstructed except the record-specific grep preserved below.

```bash
sudo grep -F 'SOC_VOLT_HUNT_VISIBILITY_TEST' /var/ossec/logs/alerts/alerts.json
```

On Splunk server, a UDP capture was used to verify arrival; equivalent read-only command:

```bash
sudo tcpdump -ni any udp port 5515
```

Result: manager alerts and incoming datagrams were observed. Effective manager forwarding had no restrictive level filter. Exact original tcpdump options and entire manager configuration dump are not preserved. Do not add a forwarding threshold to solve an unproven threshold issue.

## Phase 2 Discovery and process candidate searches

### C05 Benign discovery tests

Status: recorded commands; execute separately.

```powershell
whoami.exe /all
hostname.exe
ipconfig.exe /all
net.exe user
tasklist.exe
```

Result: Splunk 43509 whoami, 43511 hostname, 43512 ipconfig, 43514 net, 43515 net1; latter parent net.exe. Tasklist 43513 appeared locally and in Wazuh but was unlocated in Splunk. Each tool's appearance was expected operator activity.

### Q01 Wazuh JSON process extraction and discovery query

Status: recorded extraction pattern; complete reusable query. The candidate list below matches the provided discovery screenshot. Use the applicable historical time picker for September 24 evidence, rather than expecting `-24h` to recover it on October 3.

```spl
index=main source="udp:5515"
| rex field=_raw "(?<event_json>\{\"win\":.*)$"
| spath input=event_json path=win.system.eventID output=event_id
| spath input=event_json path=win.system.computer output=endpoint
| spath input=event_json path=win.system.eventRecordID output=record_id
| spath input=event_json path=win.eventdata.subjectUserName output=account
| spath input=event_json path=win.eventdata.newProcessName output=process
| spath input=event_json path=win.eventdata.parentProcessName output=parent
| spath input=event_json path=win.eventdata.commandLine output=command_line
| where event_id="4688" AND endpoint="soc-vict-win10.sochomelab.local"
| eval process_name=lower(replace(process,"^.*\\\\",""))
| where in(process_name,"whoami.exe","hostname.exe","systeminfo.exe",
    "ipconfig.exe","net.exe","net1.exe","nltest.exe","netstat.exe",
    "tasklist.exe","quser.exe","qwinsta.exe","arp.exe","route.exe")
| sort 0 _time
| table _time endpoint record_id account process_name parent command_line
```

Result: seven visible discovery entries after two later tasklist tests. The regex assumes the embedded win JSON ends the message and is complete; it does not establish ingestion completeness. A broad numeric raw search can match unrelated sudo commands and must be confirmed using extracted record IDs.

### C06 Tasklist delivery re-test

Status: captured; run twice in original investigation.

```powershell
tasklist.exe /fi "IMAGENAME eq powershell.exe"
```

Result: Windows PowerShell PID 5488 visible; Splunk records 43538 at 20:47:28 and 43539 at 20:48:27. Those two events correspond to two runs.

### Q02 Missing event pivot

Status: reconstructed targeted procedure.

```spl
index=main source="udp:5515" "43513"
| table _time _raw
```

Result: original tasklist event not located; no cause proven. Raw-name and record-specific checks did not justify concluding truncation or UDP loss.

### Q03 Higher risk tool candidate query

Status: captured corrected 4688 query. An earlier version reused logon fields and omitted process_name, producing an invalid negative result; this is the corrected form.

```spl
index=main source="udp:5515" earliest=-24h latest=now
| rex field=_raw "(?<event_json>\{\"win\":.*)$"
| spath input=event_json path=win.system.eventID output=event_id
| spath input=event_json path=win.system.computer output=endpoint
| spath input=event_json path=win.system.eventRecordID output=record_id
| spath input=event_json path=win.eventdata.subjectUserName output=account
| spath input=event_json path=win.eventdata.newProcessName output=process
| spath input=event_json path=win.eventdata.parentProcessName output=parent
| spath input=event_json path=win.eventdata.commandLine output=command_line
| where event_id="4688" AND endpoint="soc-vict-win10.sochomelab.local"
| eval process_name=lower(replace(process,"^.*\\\\",""))
| where in(process_name,"ntdsutil.exe","vssadmin.exe","diskshadow.exe",
    "reg.exe","netsh.exe","schtasks.exe","sc.exe","wmic.exe","wevtutil.exe")
| sort 0 _time
| table _time endpoint record_id account process_name parent command_line
```

Result: correct baseline initially zero, then two deliberate validation commands below. Tool-name-only hits require argument and parent review.

### C07 Portproxy and service queries

Status: captured.

```powershell
netsh.exe interface portproxy show all
sc.exe query WazuhSvc
```

Result: portproxy returned to the prompt with no entries; service query reached Splunk. Records 43612 and 43613, seclabadmin, PowerShell parent, at September 24 21:10:45 and 21:11:14. The commands only queried state.

## Phase 3 Session correlation

### C08 Original local session lookup

Status: captured procedure.

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 2000 |
    ForEach-Object {
        $event = $_
        $xml = [xml]$event.ToXml()
        $fields = @{}
        foreach ($item in $xml.Event.EventData.Data) {
            $fields[$item.Name] = $item.InnerText
        }
        if ($fields['TargetLogonId'] -eq '0x7a169') {
            [pscustomobject]@{
                TimeCreated = $event.TimeCreated
                RecordId = $event.RecordId
                Account = $fields['TargetUserName']
                Domain = $fields['TargetDomainName']
                LogonId = $fields['TargetLogonId']
                LogonType = $fields['LogonType']
                SourceIP = $fields['IpAddress']
                Workstation = $fields['WorkstationName']
                AuthPackage = $fields['AuthenticationPackageName']
            }
        }
    } | Format-List
```

Result: record 42807, September 24 19:26:15, local seclabadmin, type 2, 127.0.0.1, Negotiate.

### C09 Manager record lookup

Status: captured.

```bash
sudo grep -F '"eventRecordID":"42807"' /var/ossec/logs/alerts/alerts.json |
    grep -F 'soc-vict-win10'
```

Result: Wazuh alert exists, rule 60118 level 3, time 19:26:18.877−0600. User later confirmed receiver started after that activity.

### Q04 Splunk session lookup

Status: captured.

```spl
index=main source="udp:5515"
| rex field=_raw "(?<event_json>\{\"win\":.*)$"
| spath input=event_json path=win.system.eventID output=event_id
| spath input=event_json path=win.system.computer output=endpoint
| spath input=event_json path=win.system.eventRecordID output=record_id
| spath input=event_json path=win.eventdata.targetUserName output=account
| spath input=event_json path=win.eventdata.targetLogonId output=logon_id
| spath input=event_json path=win.eventdata.logonType output=logon_type
| spath input=event_json path=win.eventdata.ipAddress output=source_ip
| where event_id="4624" AND endpoint="soc-vict-win10.sochomelab.local"
    AND lower(logon_id)="0x7a169"
| table _time endpoint record_id account logon_id logon_type source_ip
```

Result: zero for original session. Broad rule 60118 search without session restriction found four other type 2 records, not the original session.

### Q05 Raw record and rule availability checks

Status: captured.

```spl
index=main source="udp:5515" "60118"
| where like(_raw,"%42807%")
| eval raw_characters=len(_raw)
| table _time host raw_characters _raw
```

Result: zero.

```spl
index=main source="udp:5515" "60118"
| stats count earliest(_time) AS first_seen latest(_time) AS last_seen
| convert ctime(first_seen) ctime(last_seen)
```

Result: four received events. The integrity export `1790305081_56.csv` retained record IDs, raw lengths and final fragments. Exact query that generated those final fragments is not preserved.

### Q06 Network and RDP logon query

Status: captured, based on Q04 extraction with domain added and session restriction removed.

```spl
index=main source="udp:5515"
| rex field=_raw "(?<event_json>\{\"win\":.*)$"
| spath input=event_json path=win.system.eventID output=event_id
| spath input=event_json path=win.system.computer output=endpoint
| spath input=event_json path=win.system.eventRecordID output=record_id
| spath input=event_json path=win.eventdata.targetUserName output=account
| spath input=event_json path=win.eventdata.targetDomainName output=account_domain
| spath input=event_json path=win.eventdata.targetLogonId output=logon_id
| spath input=event_json path=win.eventdata.logonType output=logon_type
| spath input=event_json path=win.eventdata.ipAddress output=source_ip
| where event_id="4624" AND endpoint="soc-vict-win10.sochomelab.local"
    AND in(logon_type,"3","10")
| sort 0 _time
| table _time endpoint record_id account_domain account logon_id logon_type source_ip
```

Result: zero in Splunk. Direct local check below returned one anonymous network logon.

### C10 Local network and RDP logons

Status: captured.

```powershell
$since = (Get-Date).AddHours(-24)
$remoteLogons = @(
    Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624; StartTime=$since} -ErrorAction Stop |
        ForEach-Object {
            $event = $_
            $xml = [xml]$event.ToXml()
            $fields = @{}
            foreach ($item in $xml.Event.EventData.Data) { $fields[$item.Name] = $item.InnerText }
            if ($fields['LogonType'] -in @('3','10')) {
                [pscustomobject]@{
                    Time = $event.TimeCreated
                    RecordId = $event.RecordId
                    Account = $fields['TargetUserName']
                    Domain = $fields['TargetDomainName']
                    LogonId = $fields['TargetLogonId']
                    LogonType = $fields['LogonType']
                    SourceIP = $fields['IpAddress']
                }
            }
        }
)
$remoteLogons | Sort-Object Time | Format-Table -AutoSize
"Matching network/RDP logons: $($remoteLogons.Count)"
```

Result: one record 42761, ANONYMOUS LOGON type 3, no source IP. No type 10 returned in that local window.

### C11 Inspect anonymous record and bounded session context

Status: exact record query captured; bounded correlation procedure reconstructed.

```powershell
Get-WinEvent -LogName Security -FilterXPath '*[System[(EventID=4624) and (EventRecordID=42761)]]' |
    Format-List TimeCreated, RecordId, Message
```

Result: session 0x2b3bc, NT AUTHORITY, source/workstation/process absent, NTLM V1 label. Equivalent session-context procedure:

```powershell
$sessionEvent = Get-WinEvent -LogName Security -FilterXPath '*[System[(EventID=4624) and (EventRecordID=42761)]]'
Get-WinEvent -FilterHashtable @{
    LogName='Security'
    StartTime=$sessionEvent.TimeCreated.AddSeconds(-5)
    EndTime=$sessionEvent.TimeCreated.AddMinutes(10)
} | Where-Object { $_.ToXml() -match '(?i)0x2b3bc' } |
    Format-List TimeCreated, Id, RecordId, Message
```

Result reported: only original event. Initial process audit gap limits correlation.

## Phase 4 Task service and signature inventory

### C12 Non-Microsoft scheduled tasks

Status: captured, with PowerShell `$_` syntax corrected from chat formatting.

```powershell
Get-ScheduledTask |
    Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
    Select-Object TaskPath, TaskName, State,
        @{Name='RunAs';Expression={$_.Principal.UserId}},
        @{Name='Actions';Expression={($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join '; '}} |
    Format-List
```

Result: 12 browser and OneDrive tasks; Security Admin account recognized. Initial duplicate paste formed `Format-ListGet-ScheduledTask` twice and failed; those runs did not enumerate tasks successfully. The later corrected run did.

### C13 Browser file signature checks

Status: captured corrected assignment pattern.

```powershell
$files = @(
    'C:\Program Files (x86)\BraveSoftware\Update\BraveUpdate.exe'
    'C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe'
    'C:\Program Files (x86)\Mozilla Firefox\firefox.exe'
    'C:\Program Files (x86)\Mozilla Firefox\default-browser-agent.exe'
)
$results = foreach ($file in $files) {
    if (Test-Path -LiteralPath $file) {
        $signature = Get-AuthenticodeSignature -LiteralPath $file
        [pscustomobject]@{File=$file; Status=$signature.Status; Signer=$signature.SignerCertificate.Subject}
    } else {
        [pscustomobject]@{File=$file; Status='File not found'; Signer=''}
    }
}
$results | Format-List
```

Result: four Valid signatures, Brave Software, Microsoft and Mozilla respectively. Initial `foreach` statement piped directly to Format-List produced an empty-pipe parser error; assignment before piping fixed it.

### C14 Profile and OneDrive signature checks

Status: reconstructed equivalent; reported outputs retained in screenshots.

```powershell
Get-CimInstance Win32_UserProfile | Select-Object SID, LocalPath, Loaded, Special | Format-List
$results = foreach ($profile in Get-CimInstance Win32_UserProfile) {
    $oneDrive = Join-Path $profile.LocalPath 'AppData\Local\Microsoft\OneDrive'
    if (Test-Path -LiteralPath $oneDrive) {
        Get-ChildItem -LiteralPath $oneDrive -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue |
            Where-Object Name -in @('OneDriveStandaloneUpdater.exe','OneDriveLauncher.exe') |
            ForEach-Object {
                $signature = Get-AuthenticodeSignature -LiteralPath $_.FullName
                [pscustomobject]@{Profile=$profile.LocalPath; File=$_.FullName; Status=$signature.Status; Signer=$signature.SignerCertificate.Subject}
            }
    }
}
$results | Format-List
```

Result recorded: seclabadmin and Security Admin updater files Valid; seclabadmin launcher Valid; SplunkForwarder service profile directory not present; no Administrator profile returned. The recursive equivalent can discover more versions than the original bounded check; it is not a verbatim historical inventory.

### C15 Microsoft task candidate review

Status: reconstructed inventory equivalent; exact historical results in chat.

```powershell
$results = foreach ($task in Get-ScheduledTask | Where-Object TaskPath -like '\Microsoft\*') {
    foreach ($action in $task.Actions) {
        if ($action.Execute -match '(?i)(powershell|rundll32|cmd|wscript|cscript|mshta)\.exe$') {
            [pscustomobject]@{TaskPath=$task.TaskPath; TaskName=$task.TaskName; State=$task.State; RunAs=$task.Principal.UserId; Execute=$action.Execute; Arguments=$action.Arguments}
        }
    }
}
$results | Format-List
```

Result recorded: Windows maintenance tasks, including SMB uninstall scripts, Pca tasks, StartupAppTask, repository cleanup and dsregcmd workplace tasks. The earlier broad expression accidentally matched dsregcmd by its suffix; the explicit executable expression here avoids that false candidate. Task arguments are in the technical narrative; full original inventory is in the session record.

### C16 SMB maintenance script signature

Status: captured.

```powershell
$scriptPath = "$env:windir\System32\WindowsPowerShell\v1.0\Modules\SmbShare\DisableUnusedSmb1.ps1"
Get-AuthenticodeSignature -LiteralPath $scriptPath |
    Select-Object Path, Status, @{Name='Signer';Expression={$_.SignerCertificate.Subject}} |
    Format-List
```

Result: Valid, Microsoft Windows. A valid file signature alone does not verify every task definition.

### C17 Nonstandard-path service inventory

Status: reconstructed equivalent of results-only supplied inventory.

```powershell
Get-CimInstance Win32_Service |
    Where-Object { $_.PathName -and $_.PathName -notmatch '(?i)\\Windows\\(System32|SysWOW64)\\' } |
    Select-Object Name, State, StartMode,
        @{Name='RunAs';Expression={$_.StartName}},
        @{Name='Path';Expression={$_.PathName}} |
    Format-List
```

Result: browsers, Defender, SplunkForwarder, Wazuh, VMware, Update Health Tools and Windows Media Player. Running/stopped status was not interpreted as disabling by an actor.

### C18 Historical service installs

Status: captured, used at two different dates.

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; Id=7045; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
    Sort-Object TimeCreated |
    Format-List TimeCreated, RecordId, Message
```

Earlier result: KslD record 3967, VMware records 4106 and 4115. Latest October 3 result: prompt returned with no entries. Suppressed errors limit assurance; no-results is not independent proof of channel readability. A later duplicate paste joined `MessageGet-WinEvent` and failed before the corrected one-line rerun.

### C19 KslD driver validation

Status: captured.

```powershell
$driverPath = "$env:windir\System32\drivers\wd\KslD.sys"
if (Test-Path -LiteralPath $driverPath) {
    Get-AuthenticodeSignature -LiteralPath $driverPath |
        Select-Object Path, Status, @{Name='Signer';Expression={$_.SignerCertificate.Subject}} |
        Format-List
    (Get-Item -LiteralPath $driverPath).VersionInfo |
        Select-Object CompanyName, FileDescription, ProductName, FileVersion |
        Format-List
} else { "File not present: $driverPath" }
```

Result: Valid Microsoft Windows; Microsoft Malware Protection, version 1.1.26080.64012. Operator recognized VMware installation timing.

## Phase 5 Network and firewall checks

### C20 Live connection ownership

Status: captured.

```powershell
$results = Get-NetTCPConnection -State Established | ForEach-Object {
    $connection = $_
    $owner = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
    [pscustomobject]@{
        LocalAddress=$connection.LocalAddress; LocalPort=$connection.LocalPort
        RemoteAddress=$connection.RemoteAddress; RemotePort=$connection.RemotePort
        ProcessId=$connection.OwningProcess; ProcessName=$owner.ProcessName; ProcessPath=$owner.Path
    }
}
$results | Sort-Object ProcessName, RemoteAddress | Format-List
Get-CimInstance Win32_Service | Where-Object { $_.ProcessId -in @(3300,3552) } |
    Select-Object Name, DisplayName, State, ProcessId, PathName | Format-List
```

Result: Defender, Windows push notifications and Wazuh connections as detailed in report. Blank protected-process path did not alone imply suspiciousness; CIM resolved service paths.

### Q07 Source inventory

Status: captured.

```spl
index=main earliest=-24h latest=now NOT source="udp:5515"
| stats count latest(_time) AS last_seen by host source sourcetype
| convert ctime(last_seen)
| sort - count
```

Result: 25 syslog entries from host 10.10.10.5, source udp:5140, latest September 24 21:09:51. CSV contained DHCP events, not victim traffic visibility. A separate address search returned no results; exact first address-search syntax not preserved.

### C21 Splunk UDP input configuration

Status: captured on Splunk server.

```bash
sudo /opt/splunk/bin/splunk btool inputs list 'udp://5515' --debug
```

Result: launcher/local inputs.conf, index main, sourcetype syslog, connection_host ip, host soc-siem-splunk; rcvbuf 1572864 from default. This is UDP 5515 configuration, not the later TCP receiver configuration.

### U01 pfSense remote logging and effective rule inspection

Status: captured UI procedure and shell diagnostic.

1. Inspect Status → System Logs → Settings: destinations 10.10.10.10:5514 and 10.10.10.14:5140; Firewall Events checked along with selected other categories.
2. Inspect first Corporate allow rule: log checkbox initially unchecked; enable, save and apply; subsequently confirmed checked.
3. Inspect Firewall logs and source/destination filters. Tests still absent from intended rule.
4. Run in Diagnostics → Command Prompt → Execute Shell Command:

```sh
pfctl -vvsr
```

Result: floating @94 tracker 1786962198 pass quick IPv4 any-to-any, before logged Corporate @97 tracker 1786792812. Floating had 5,855,163 packets and 5,189,784,475 bytes in the supplied snapshot; intended Corporate rule had zero packets/states. Effective counters identified the earlier match.

### C22 Fresh connectivity tests

Status: captured Windows commands, destinations varied across tests.

```powershell
Get-Date -Format o
Test-NetConnection -ComputerName 1.1.1.1 -Port 443 -InformationLevel Detailed
Test-NetConnection -ComputerName 1.0.0.1 -Port 443 -InformationLevel Detailed
Test-NetConnection -ComputerName 1.1.1.1 -Port 80 -InformationLevel Detailed
Test-NetConnection -ComputerName 1.0.0.1 -Port 80 -InformationLevel Detailed
```

Result: source 10.10.20.20, Ethernet0, next hop 10.10.20.5, TcpTestSucceeded True. These were connectivity probes, not exploitation. Run-specific timestamps and ports must be taken from evidence rather than attributing every destination event to a single command.

### U02 Effective logging and timestamp repair

Status: recorded procedure.

1. Enable logging on the matching floating rule temporarily, save and apply.
2. Generate fresh port 80 test and inspect local and Splunk logs.
3. Change pfSense system timezone from MST to America/Denver.
4. Check shell time and emit a labeled system logger message:

```sh
date '+%Y-%m-%d %H:%M:%S %Z %z'
logger -t SOC_TIME_TEST "SOC_TIME_TEST_AFTER_TZ_CHANGE"
```

Result: system date 20:35:18 MDT−0600; SOC_TIME_TEST at 20:36:12 matched, but filterlog5400 remained one hour behind.

### C23 Attempted filter logger restart

Platform: pfSense Execute PHP Commands, not shell. Status: captured unsuccessful restart attempt.

```php
require_once("/etc/inc/filter.inc");
filter_pflog_start(true);
echo "Firewall logging restart requested.";
```

Result: echo returned; PID remained 5400. Do not interpret echo as success. Verification command:

```sh
date '+%Y-%m-%d %H:%M:%S %Z %z'; pgrep -laf filterlog; cat /var/run/filterlog.pid
```

Result: October-independent September 25 20:53:45 MDT, running filterlog5400 and pidfile5400; shell command itself also matched pgrep, so use the actual filterlog process line.

### Q08 Timestamp searches

Status: captured sequential queries.

```spl
index=main source="udp:5140" earliest=-10m latest=now
"filterlog" "10.10.20.20" "1.0.0.1"
| sort 0 - _time
| head 1
| table _time _raw
```

A short-window run returned no results. The wider query returned three endpoint rows:

```spl
index=main source="udp:5140" earliest=-24h latest=+2h
"filterlog" "10.10.20.20" "1.0.0.1"
| eval received_time=strftime(_indextime,"%Y-%m-%d %H:%M:%S %z")
| sort 0 - _indextime
| head 10
| table received_time _time _raw
```

Results 20:32:04, 20:41:53 and 20:47:45 receipt/event time versus embedded 19:32:04, 19:41:53 and 19:47:45. The reason the shorter search missed the event was not conclusively established. After reboot, fresh event 20:57:48 had aligned fields and PID 52199.

### U03 Disable broad floating rule

Status: captured UI change.

1. Confirm new management access via https://10.10.10.5; retain VM console.
2. In Floating rule tracker1786962198, check Disable this rule, Save and Apply Changes.
3. Confirm access in fresh management tab and run new port80 test.
4. Leave existing states alone.

Result: September 25 21:05:42 Corporate pass to 1.0.0.1:80 from source port54926, matching temporary internet access tracker1786792812. Screenshot of full seventh row corroborates. Config backup was recommended before this change; the conversation does not independently confirm backup completion. Full segmentation not completed.

### Q09 Firewall hunt export

Status: captured.

```spl
index=main source="udp:5140" earliest=-30m latest=now
"filterlog" "10.10.20.20"
| sort 0 _time
| table _time _raw
```

Result: 7,846 rows in 1790392172_310.csv. Most were repeated SYNs to 10.10.10.14:9997. Counts are log records, not connections. Parser used the IPv4 format observed in all rows; other formats require separate parsing.

## Phase 6 Direct forwarder diagnosis

### C24 Splunk connection ownership

Status: captured victim query.

```powershell
Get-NetTCPConnection -RemoteAddress 10.10.10.14 -ErrorAction SilentlyContinue |
    Select-Object LocalPort, RemoteAddress, RemotePort, State, OwningProcess,
        @{Name='ProcessName';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
    Format-Table -AutoSize
```

Result: splunkd3596, 9997 SynSent, 8089 Established. Current owner attribution is not independent proof of every earlier packet owner.

### C25 Receiver checks

Platform: Splunk Linux server. Status: captured.

```bash
sudo ss -lntp 'sport = :9997'
sudo /opt/splunk/bin/splunk btool inputs list 'splunktcp://9997' --debug
```

Result before remediation: headings only for ss, no receiver stanza for btool; no listener and no effective receiver configuration observed. Btool repeated twice in screenshot, both empty.

### U04 Enable receiver and verify transport

Status: captured procedure, October 3 follow-up.

1. Splunk Web → Settings → Forwarding and receiving → Receive data → Configure receiving → New Receiving Port.
2. Enter9997 and save.
3. Re-run server ss from C25.

Result: 0.0.0.0:9997 LISTEN owned by splunkd PID 1942. Victim verification:

```powershell
Get-NetTCPConnection -RemoteAddress 10.10.10.14 -RemotePort 9997 -ErrorAction SilentlyContinue |
    Format-Table LocalPort, RemoteAddress, RemotePort, State, OwningProcess -AutoSize
```

Result: source51200 Established3596, two older TimeWait rows; ingestion not assumed until Q10/Q11.

### Q10 Direct source inventory

Status: captured.

```spl
index=* earliest=-15m latest=now NOT source="udp:5515" NOT source="udp:5140"
| stats count latest(_time) AS last_seen by index host source sourcetype
| convert ctime(last_seen)
| sort - count
```

Result: 98 entries: CPU 34, Network 34, AvailableMemory 17, Application 6, System 5, FreeDisk 2. Security absent in that snapshot; this alone did not prove disabled collection.

### C26 Effective Security collection configuration

Status: captured.

```powershell
& 'C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe' btool inputs list 'WinEventLog://Security' --debug
```

Result: app-local stanza, disabled0, current_only0, start_fromoldest, checkpointInterval5, interval60, index=default, hostdecideOnStartup. Configuration is not proof that every historic event backfilled.

### Q11 Broader Security availability query

Status: captured, time picker Last24hours.

```spl
index=* OR index=_*
| search host="soc-vict-win10" source="WinEventLog:Security"
| stats count latest(_time) AS last_seen by index host source sourcetype
| convert ctime(last_seen)
```

Result: 845 events in main, latest October 3 02:15:59.067. Earlier assistant internal-index explanation for index=default was incorrect; main destination confirmed. Wider period and continued ingestion both changed between snapshots; cause of first empty Security inventory not isolated.

### Q12 Security event coverage

Status: captured.

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
earliest=-24h latest=now
| stats count latest(_time) AS last_seen by EventCode
| convert ctime(last_seen)
| sort - count
```

Result: 4688=620;5379=196;4798=29;4624=15;4672=14;4799=9;5382=4;4634=2;4616=1;4648=1;5038=1. These event totals are a source snapshot, not all fully investigated categories.

### Q13 Raw process export

Status: captured.

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
EventCode=4688 earliest=-24h latest=now
| sort 0 _time
| table _time _raw
```

Result: 626 rows in 1791015702_411.csv, all command lines populated. Six additional events relative to Q12 reflect later snapshot, not duplicate finding. Derived complete extraction attached.

## Phase 7 Defender Code Integrity

### Q14 Integrity candidate export

Status: captured.

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
EventCode=5038 earliest=-24h latest=now
| sort 0 _time
| table _time _raw
```

Result: one event 47412, DefenderSessionHelper.exe, October 3 01:58:47.320.

### C27 Current Defender file signature

Status: captured.

```powershell
$file = 'C:\ProgramData\Microsoft\Windows Defender\Platform\4.18.26080.4-0\DefenderSessionHelper.exe'
Get-AuthenticodeSignature -LiteralPath $file |
    Select-Object Path, Status, StatusMessage, @{Name='Signer';Expression={$_.SignerCertificate.Subject}} |
    Format-List
```

Result: Valid, Signature verified, Microsoft Windows. Current signature validity does not explain historic validation context by itself.

### C28 Nearby Code Integrity events

Status: captured corrected run.

```powershell
$start = Get-Date '2026-10-03 01:56:00'
$end = Get-Date '2026-10-03 02:01:00'
Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-CodeIntegrity/Operational'
    StartTime=$start
    EndTime=$end
} -ErrorAction SilentlyContinue |
    Sort-Object TimeCreated |
    Format-List TimeCreated, Id, Message
```

Result: 3004 and 3089 at 01:58:47. A merged paste appended `$start = Get-Date` to Format-List and failed; corrected second execution returned evidence.

### C29 Signature XML and correlation XML

Status: captured.

```powershell
Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-CodeIntegrity/Operational'
    Id=3089
    StartTime=$start
    EndTime=$end
} | ForEach-Object { $_.ToXml() }
```

```powershell
Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-CodeIntegrity/Operational'
    Id=3004
    StartTime=Get-Date '2026-10-03 01:56:00'
    EndTime=Get-Date '2026-10-03 02:01:00'
} | ForEach-Object { $_.ToXml() }
```

Result: matching ActivityID c6bc20a0-4c8c-0000-0730-bfc68c4cdd01; requester MsMpEng, RequestedSigningLevel 7;3089 publisher Microsoft Windows, ValidatedSigningLevel 12, VerificationError 12. Classified as PPL signing mismatch, root cause unresolved. Chat-supplied XML preserved separately, labeled as transcribed evidence.

## Phase 8 Logons and persistence audit coverage

### Q15 Local logon and explicit credential export

Status: captured.

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
(EventCode=4624 OR EventCode=4648)
earliest=-24h latest=now
| sort 0 _time
| table _time EventCode _raw
```

Result: 19 records;16 type 5 SYSTEM; 2 linked type 2 seclabadmin; 1 localhost 4648. Operator confirmed 02:04 local sign-in. No type 3/10 in export.

### Q16 Security persistence and clearing search

Status: captured.

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
(EventCode=4697 OR EventCode=4698 OR EventCode=4702 OR EventCode=1102)
earliest=-24h latest=now
| sort 0 _time
| table _time EventCode _raw
```

Result: no results. Subsequent audit policy showed missing service/task coverage. Log-clear coverage not independently validated by those two audit checks. Negative result cannot be promoted to blanket persistence assurance.

### C30 Audit policy checks and change

Status: captured. Initial checks both No Auditing; repeated old screenshot was not proof of applied settings.

```powershell
auditpol /get /subcategory:"Security System Extension"
auditpol /get /subcategory:"Other Object Access Events"
auditpol /set /subcategory:"Security System Extension" /success:enable
auditpol /set /subcategory:"Other Object Access Events" /success:enable
auditpol /get /subcategory:"Security System Extension"
auditpol /get /subcategory:"Other Object Access Events"
```

Result: final screenshot both Success. No task/service event validation or policy-refresh persistence test completed.

### C31 Task history availability

Status: captured.

```powershell
Get-WinEvent -ListLog 'Microsoft-Windows-TaskScheduler/Operational' |
    Format-List LogName, IsEnabled, RecordCount, LastWriteTime
```

Result: enabled True, 17,448 records, last write October 3 02:37:19.

### C32 Seven day task change export

Status: captured.

```powershell
Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-TaskScheduler/Operational'
    Id=106,140,141
    StartTime=(Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue |
    Sort-Object TimeCreated |
    Format-List TimeCreated, Id, RecordId, Message |
    Out-File -LiteralPath "$env:USERPROFILE\Desktop\TaskScheduler-Hunt.txt" -Encoding utf8 -Width 4096
```

Result: file supplied from host Downloads; 212 events, 210 updates and 1 deletion/1 registration for the same OneDrive task. No unexplained task names. Task messages lack action definitions; task-path familiarity is not verification of actions.

## Unexecuted follow-up validation and detection queries

These procedures are proposed next work, not evidence that was performed. Execute only after reviewing current lab state. Use a uniquely named temporary task so existing tasks are not changed. A service installation test is not included because it is unnecessary for a first task-audit validation.

### P01 Harmless scheduled task audit test

```powershell
$taskName = 'SOC-Hunt-AuditValidation-20261003'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    throw 'Validation task already exists; choose a different name before proceeding.'
}
$action = New-ScheduledTaskAction -Execute "$env:windir\System32\cmd.exe" -Argument '/c exit 0'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddDays(1)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description 'Temporary SOC audit validation task' | Out-Null
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
```

Expected, not yet observed: local 4698 creation and 4699 deletion, task Operational history, then direct Splunk Security receipt. Task is not intentionally run. Search:

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
(EventCode=4698 OR EventCode=4699) earliest=-15m latest=now
"SOC-Hunt-AuditValidation-20261003"
| table _time EventCode _raw
```

### P02 Security sensitive behavior triage

Proposed raw-search triage; not a production analytic and not validated against baseline. Review full command arguments and parents, including known Wazuh configuration assessments.

```spl
index=main host="soc-vict-win10" source="WinEventLog:Security"
EventCode=4688 earliest=-24h latest=now
("ntdsutil" OR "vssadmin" OR "diskshadow" OR "comsvcs.dll"
 OR "procdump" OR "portproxy" OR "wevtutil" OR "schtasks")
| sort 0 _time
| table _time _raw
```

Expected false candidates include maintenance wevtutil manifests and benign portproxy show queries. Do not alert on names without distinguishing query/configuration/dump/clear operations.

### P03 Historical fixed windows

To repeat the original October 3 process review later, set the Splunk custom time picker to October 3 01:54:00–02:21:00 in the display timezone and remove rolling earliest/latest. For the firewall review, use September 25 20:39:00–21:10:00 and retain timestamp qualifications. Record user timezone, query execution time, ingestion lag and export filename in future case logs.

## Failed attempts and corrections register

| Attempt | Observed failure or analytic issue | Correction and reporting consequence |
| --- | --- | --- |
| Task inventory pasted twice | Format-ListGet-ScheduledTask not recognized | Paste once with newline; failed run excluded from evidence counts |
| foreach piped directly | Empty pipe element parser error | Assign results then pipe |
| Logon query reused for process names | process_name not extracted | Complete4688 query before interpreting zero |
| Record number searched broadly | Unrelated sudo raw matches possible | Confirm event record, endpoint and eventID |
| Logger PHP echo | Said restart requested but PID 5400 remained | Inspect actual process; reboot then fresh-event validation |
| CSV1790390530_296 | Same earlier event exported | Generate fresh connection rather than reusing old result |
| Short firewall search | No results while broader/local evidence existed | Expand time and compare `_indextime`; cause not isolated |
| index=default interpretation | Internal-index suggestion unsupported | mainSecurity destination established by evidence |
| Code Integrity multiline paste | Message$start merged into Format-List | Corrected independent execution produced3004/3089 |
| System7045 duplicate paste | MessageGet-WinEvent; parameterbinding error | Single-line rerun; then no entries reported |
| User sent old audit screenshot | StillNoAuditing, /set not shown | New screenshot verifiedSuccess for both |

**TLP:CLEAR**

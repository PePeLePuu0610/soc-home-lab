# Operations command and query register

October 8, 2026 retrospective update. Recorded queries are distinguished from reconstructed examples. Use an appropriate time window and the correct data view. These searches do not change configuration.

## Wazuh dashboard — recorded
Data view: wazuh-alerts-* on the Wazuh dashboard.

DC Defender channel:
```text
agent.id: "002" AND data.win.system.channel: "Microsoft-Windows-Windows Defender/Operational"
```
Last 24 hours returned 23 hits in the supplied evidence. Last 30 minutes previously returned no results; cause was not established.

Detection pivot supplied during troubleshooting:
```text
agent.id: "002" AND data.win.system.eventID: "1116"
```
General DC / victim search:
```text
agent.id: "002"
agent.id: "001"
```
Execute each separately. The victim-only query appeared in earlier investigation evidence; current post-reboot victim delivery still needs confirmation.

Observed columns: Time, data.win.system.eventID, rule.description, rule.id. Event1116 matched rule62123; event1117 matched rule62124 at 15:56 and16:03 displayed times. See [Defender validation](defender-telemetry-validation-2026-10-08.md).

## ELK — reconstructed query examples, not claimed executed
Exact recent firewall query strings and field mappings were not fully preserved. In the pfSense data view, use observed mapped fields if present:
```text
source.ip: "10.10.10.12" AND destination.ip: "10.10.20.10"
source.ip: "10.10.30.10"
```
If these fields do not exist, inspect a known document first. A raw-message fallback example:
```text
message: "10.10.10.12" AND message: "10.10.20.10"
```
Confirm action, interface, destination port, tracker and timestamp from each actual record. Index absence or a field mismatch is not proof of traffic absence. Historical successful ELK ingestion is documented in [integration validation](integration-validation.md); repeat post-reboot verification.

## DC PowerShell — recorded
```powershell
Get-Service -Name RemoteRegistry
Get-Service -Name Winmgmt
Get-Service -Name LanmanServer
Get-Service -Name WazuhSvc
```
RemoteRegistry was stopped and subsequently started with Start-Service -Name RemoteRegistry; all four services were shown Running across supplied screenshots.

Recorded channel diagnostic:
```powershell
Select-String -Path 'C:\Program Files (x86)\ossec-agent\ossec.log' -Pattern 'Defender' | Select-Object -Last 10
```
Channel-open log establishes initialization, not end-to-end delivery. Successful alert evidence established delivery later.

## OpenVAS VM — recorded export commands
```bash
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml ps -a > ~/openvas-validation-status.txt
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml logs --since 15m --tail 200 gvmd ospd-openvas openvasd > ~/openvas-validation-logs.txt 2>&1
```
Status showed running scanner components and healthy gvmd/PostgreSQL. Log file was zero bytes; that is not evidence of error-free operation.

## Earlier threat hunt
The extensive historical command/query record is already under [Hunt001 command and query log](hunts/volt-typhoon-informed-2026/command-query-log.md), including captured commands, reconstructed equivalents, unsuccessful searches and coverage limits. This new register supplements it.

## Evidence practice
Store original screenshots, CSV/EVTX and exports privately. Record time/timezone, query, data view, filters, event count, representative record and interpretation. Never present a reconstructed query as the exact historical execution.


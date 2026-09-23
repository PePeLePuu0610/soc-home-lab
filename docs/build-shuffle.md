# Shuffle Deployment and Response Validation — Step 3.9

## Outcome and scope

Validated on September 21–22, 2026 from operator terminal output and workflow screenshots. Shuffle receives a controlled Windows Application error through Wazuh, filters on an exact marker, authenticates to the Wazuh API, and creates a marker file on Windows agent `001`. A separate manually started workflow removes the file. This demonstrates orchestration and reversible endpoint execution; it does not demonstrate isolation, malicious-process termination, or AD account disabling.

TheHive and Cortex are deferred. Both SIEM integrations and the limited OpenVAS scan were already recorded in [Integration and Validation](integration-validation.md).

## As-built deployment

| Setting | Observed value |
|---|---|
| Hostname / address | `soc-soar-shfl` / `10.10.10.13/24` |
| Gateway / network | `10.10.10.5` / Management VMnet1 |
| OS / resources | Ubuntu 24.04.5 LTS; 4 vCPU; about 7.7GiB RAM visible; 98GB root filesystem |
| Docker / Compose | Engine 29.8.1; Compose v5.5.1 |
| Checkout | `/home/seclabadmin/Shuffle`, upstream `Shuffle/Shuffle` |
| Core services observed running | frontend, backend, orborus, opensearch |
| Database | OpenSearch 3.2.0; about 3.45GiB memory in the observed idle snapshot |
| Published ports observed | frontend 3001/3443; backend 5001; OpenSearch 9200 |
| Scope | Shuffle only; optional `shuffle-security` service was not explicitly started |

Verified gateway ping, DNS resolution, package update, Docker hello-world, Compose configuration validation, container status, admin login, and a local workflow. Created `shuffle-apps`, `shuffle-files`, and `shuffle-database`; set database ownership to UID/GID 1000. The `.env` file was restricted to mode 600. Orborus also created worker/app containers; do not treat that dynamic list as a fixed Compose service manifest.

Recorded non-secret configuration: `OUTER_HOSTNAME=10.10.10.13`, `SSO_REDIRECT_URL=http://10.10.10.13:3001`, `TZ=America/Denver`, `SHUFFLE_ORBORUS_EXECUTION_CONCURRENCY=1`, `SHUFFLE_APP_REPLICAS=1`, `DB_LOCATION=/home/seclabadmin/Shuffle/shuffle-database`, and `DOCKER_API_VERSION=1.44`. Database passwords and encryption modifier are intentionally omitted. Their live values must be backed up privately; changing the encryption modifier can affect saved credentials.

`SOC Lab - Execution Validation` ran `repeat_back_to_me` with `SOC_SHUFFLE_EXECUTION_TEST`. It finished before reboot and again after reboot. This verifies observed recovery and persistence; the exact restart-policy configuration and deployment commit/image digests were not captured in this record. The alert/response chain itself has not been retested after a later reboot.

## Wazuh alert forwarding

Bundled scripts `/var/ossec/integrations/shuffle` and `shuffle.py` were present with executable permissions and `root:wazuh` ownership. Added this integration inside an existing `ossec_config` block on the manager, preserving existing SIEM forwarding and Indexer settings:

```xml
<integration>
  <name>shuffle</name>
  <hook_url>REPLACE_WITH_PRIVATE_SHUFFLE_WEBHOOK_URL</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>
```

The placeholder is not deployable as written. Copy the actual webhook URL privately from the running on-prem trigger. Restarted the manager and verified `wazuh-integratord` running with Shuffle enabled. A manual JSON POST first established network transport and execution; that synthetic payload alone did not prove Windows collection.

The actual Windows test, run in Administrator PowerShell:

```powershell
eventcreate /T ERROR /ID 100 /L APPLICATION /SO SOC-Lab /D "SOC_WAZUH_SHUFFLE_AUTO_TEST"
```

Wazuh generated rule `60602`, level 9, for agent `001` (`soc-vict-win10`, `10.10.20.20`). Alert `1790050233.205249` matched across `alerts.json` and Shuffle. Wazuh's integration wraps the original alert under `all_fields`; its top-level `severity: 3` is an integration mapping, not the original Wazuh level 9.

## Automatic response workflow

Workflow: **SOC Lab - Wazuh Alert Response**.

```text
Webhook 1 -> Show Wazuh Alert -> [marker equals condition]
          -> Matched Test Alert -> Wazuh API Login -> Create Lab Marker
```

Both Tools actions use `repeat_back_to_me` with Call `$exec`. `Show Wazuh Alert` remains the starting app action. Put the condition between the two Tools actions, not on the webhook-to-start connection:

| Condition field | Value |
|---|---|
| Source | `$exec.all_fields.data.win.eventdata.data` |
| Comparison | equals |
| Destination | `SOC_WAZUH_SHUFFLE_AUTO_TEST` |

Negative test: create the same Windows event with description `SOC_WAZUH_SHUFFLE_NEGATIVE_TEST`. The webhook and first action still run; `Matched Test Alert` is **SKIPPED**. Enable **Show skipped actions** in execution details to see it. Alert `1790054440.281556`, run starting 23:20:42 on September 21, supplied the negative evidence. A subsequent positive webhook run at 23:34:13 completed both Tools actions. Later validation added the API login and response nodes; a full negative test including those new nodes remains a useful regression check.

### API identity and authentication

Created policy `shuffle_lab_response`: allow `agent:read` and `active-response:command` on `agent:id:001`. Role `shuffle_lab_operator` had ID 100; API user `shuffle_lab` also had ID 100 in this installation and was assigned that role. IDs are installation-specific. This limits the target agent, not the specific active-response script that the account may invoke.

The initial unauthenticated API check returned 401 as expected. A documented `wazuh-wui` password failed; comparison with the dashboard's working API credential resolved authentication without resetting the shared account. The new dedicated user's first lookup returned 401, but fresh authentication and the same permissions subsequently returned 200 with agent `001` active. The transient cause was not established.

| Login node setting | Value |
|---|---|
| Name / HTTP action | Wazuh API Login / POST |
| URL | `https://10.10.10.11:55000/security/user/authenticate` |
| Basic-auth username | `shuffle_lab` |
| Password | Private dedicated credential |
| Header / body | `Content-Type: application/json` / `{}` |
| Verify | `false` during this lab validation |

The HTTP app returns the JSON under `body`; the next node references `$wazuh_api_login.body.data.token`. Obtain a fresh token per execution rather than pasting an expiring token. Screenshots/exports of login results and request headers can expose tokens and must be redacted.

### Endpoint response

Installed two fixed-purpose batch scripts in `C:\Program Files (x86)\ossec-agent\active-response\bin`: `soc-marker-create.cmd` and `soc-marker-remove.cmd`. Sanitized copies are in `configs/wazuh/active-response/` in the repository. They read one input line; they do not evaluate alert content as a command. Creation writes only `C:\ProgramData\SOC-Lab\shuffle-response-marker.txt`; removal checks for the expected content before deleting that file. They are a stateless lab demonstration, not a general-purpose incident response implementation.

Local tests proved creation and removal before testing the API. Custom script requests use the `!` prefix; no new manager command/active-response blocks were added for this direct API route. The agent service `WazuhSvc` was running.

| Create node setting | Value |
|---|---|
| Name / action | Create Lab Marker / PUT |
| URL | `https://10.10.10.11:55000/active-response?agents_list=001` |
| Basic-auth fields | Empty |
| Verify | `false` |

Headers (Authorization is one logical line):

```text
Content-Type: application/json
Authorization: Bearer $wazuh_api_login.body.data.token
```

Body:

```json
{"command":"!soc-marker-create.cmd","arguments":[]}
```

The saved workflow was triggered by a fresh matching Windows event. `Create Lab Marker` returned HTTP 200, affected agent `001`, and zero failures. Windows `Get-Content` returned `SOC_SHUFFLE_RESPONSE_TEST`, proving execution beyond API acceptance.

## Separate manual reversal

Workflow: **SOC Lab - Response Reversal**.

```text
Start Reversal -> Wazuh API Login -> Remove Lab Marker
```

`Start Reversal` uses `repeat_back_to_me` with `SOC_SHUFFLE_REVERSAL_TEST`. There is no webhook; the operator starts the saved workflow with Play. Login and PUT settings match the automatic workflow, with this replacement body:

```json
{"command":"!soc-marker-remove.cmd","arguments":[]}
```

The manual Shuffle removal node returned HTTP 200. On Windows:

```powershell
Test-Path 'C:\ProgramData\SOC-Lab\shuffle-response-marker.txt'
```

returned `False`. An earlier direct API removal test independently reported agent `001` and zero failures. The final cropped Shuffle reversal screenshot shows 200 but not its expanded per-agent counts; endpoint absence provides the execution evidence. Reversal is manual, not a timed automatic rollback.

## Troubleshooting lessons retained

- A shell wildcard expands before `sudo`; use privileged `find` to inspect restricted integration directories.
- Distinguish synthetic curl payloads from real Wazuh alerts by marker and alert ID, not just latest-run time.
- Version History contains saved workflow edits; Debug contains executions. Green runtime status is not run completion.
- Conditions on the starting trigger connection did not gate the first action in this test. Moving the condition between app actions and inspecting SKIPPED resolved validation.
- Condition counts could remain stale until Save and browser refresh. Confirm actual saved conditions and arrow direction.
- Select POST or PUT before looking for the HTTP Body field; GET did not expose it.
- API 200 means the command was sent, not that the endpoint effect occurred. Always check the marker on Windows.
- JSON API bodies belong inside the request configuration/script, not directly at a Bash prompt (`!` caused history expansion).

## Evidence and remaining work

| Check | Result |
|---|---|
| Docker / Compose / admin login | Passed |
| Execution before and after VM reboot | Passed |
| Real Wazuh alert delivered with matching ID | Passed |
| Positive condition | Downstream Tools action succeeded |
| Negative condition | Downstream Tools action skipped |
| Dedicated API account read / response on 001 | Passed |
| Automatic workflow creates endpoint marker | Passed |
| Separate manual Shuffle workflow removes marker | Passed |

Evidence was reviewed in this conversation. The repository contains untracked operator screenshots, but they have not been bulk-published or fully reviewed for secrets. Curate redacted images for deployment/reboot, positive/negative action statuses, response HTTP result plus file contents, and reversal HTTP result plus `False`. Sanitized workflow JSON exports have not been supplied; documentation is not an importable workflow backup.

Before wider use: replace API certificate-verification bypass with trusted CA validation; review HTTP frontend access and published backend/database ports; move credentials to the platform's managed authentication/secret facilities where supported; pin/capture upstream commit and image digests; back up configuration, encryption modifier, and database privately. Record a post-completion snapshot and run the full response/reversal chain after reboot. Keep the existing SIEM retention, timestamp, parser, temporary Suricata rule, and OpenVAS coverage follow-ups open.

Phase 4 attack simulation and network segmentation remain separate acceptance work. The controlled marker validates Step 3.9's agreed scope only.

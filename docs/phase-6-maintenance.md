## PHASE 6 — Maintenance

**Goal:** Keep the lab useful over time instead of it rotting after week one.

## Lab startup checklist

- [ ] Select the smallest viable pod and check host available RAM and VM/host disk space before starting additional VMs. Include the DC when domain/DNS dependencies require it.
- [ ] Confirm required services and fresh telemetry, not only console/GUI access. Check pfSense syslogd remains running; a green status at boot does not establish continued delivery.
- [ ] For scanner sessions, inspect existing tasks/reports before starting another scan.
- [ ] **OpenVAS feed freshness gate:** open Administration → Feed Status and record NVT, SCAP, CERT and GVMD_DATA versions/status. If stale or syncing, complete the feed maintenance below before a new assessment. Reviewing historical reports does not require a new feed import.
- [ ] Verify endpoint scan readiness: domain profile, RemoteRegistry/Winmgmt service state, scanner-scoped firewall rules and credentials. Keep Defender enabled. See [endpoint build guide](build-windows-endpoint-scan-readiness.md).
- [ ] Record readiness results and unresolved exceptions in the day's activity log. Power off unused pods after the task.

## OpenVAS feed-only maintenance

Check feeds whenever OpenVAS is started for scanning, especially after lab downtime. Refresh when stale; do not blindly download feeds at every startup. Feed freshness is separate from Ubuntu host patching and scanner application-image updates. A host package upgrade does not refresh these feeds.

### Preparation

1. Confirm no scans are running. Record existing feed versions, current container images and available disk/RAM. Preserve exported reports privately.
2. Confirm a suitable recovery point exists. Feed imports alter shared feed volumes and databases; restarting an older image alone is not a complete rollback. Plan application-image/Compose changes separately, retaining local customizations and checking upstream compatibility.
3. Keep the approved scanner pod running and unnecessary VMs off. Do not start a new assessment while feed import is incomplete.

### Download and load feed data

Run on the OpenVAS host, one command at a time. Proceed to the second only if the download succeeds:

```sh
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml pull notus-data vulnerability-tests scap-data dfn-cert-data cert-bund-data report-formats data-objects
```

```sh
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml up -d notus-data vulnerability-tests scap-data dfn-cert-data cert-bund-data report-formats data-objects
```

These commands select feed services; they do not intentionally pull the complete application stack. Running scanner/manager daemons automatically import the copied feed data. Completion of pull/up alone is not completion of synchronization. Import can take minutes to hours.

### Validation and acceptance

- [ ] Inspect container state and recent import logs:

```sh
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml ps -a
sudo docker compose -f /home/seclabadmin/greenbone-ce/compose.yaml logs --since 30m --tail 100 ospd-openvas gvmd
```

- [ ] Confirm relevant import completion, such as `Finished loading VTs`, `Updating VTs in database ... done`, `Updating SCAP info succeeded`, and `Updating CERT info succeeded`. Logs may rotate or imports may take longer than the shown window; absence in this sample alone is not failure.
- [ ] Refresh Administration → Feed Status: record final versions and confirm no synchronization is still active and no stale status remains. Do not require a literal same-day feed timestamp if no newer upstream feed is available; document that exception.
- [ ] Verify saved targets, credentials references, custom scan configuration and historical reports remain accessible. Never record credential secrets.
- [ ] Only then permit a new scan. Feed refresh alone does not close the native WMI authentication-setting issue.

If import fails, capture logs and check resources; avoid repeated blind restarts. Do not delete volumes or run `down -v`. Restore a recovery point only under a deliberate rollback plan, accounting for reports/settings created since that point.

Source: [Greenbone Community Containers feed synchronization workflow](https://greenbone.github.io/docs/latest/22.4/container/workflows.html#performing-a-feed-synchronization).

## Maintenance cadence

- **Weekly:** Power on your current pod, run one attack scenario end-to-end, confirm detection still works.
- **Monthly:** Patch pfSense, Wazuh, and whichever SIEM you're actively using (staying current matters — this mirrors real patch management, which is itself something SOC analysts monitor for).
- **Ongoing:** Add new attack scenarios (e.g., simulate ransomware behavior, phishing payloads, lateral movement) and confirm each is detected — this is what turns the lab from a one-time build into an actual skills portfolio.
- **Before interviews:** Take screenshots of your dashboards, alerts, and SOAR playbooks — this lab is resume/portfolio material.

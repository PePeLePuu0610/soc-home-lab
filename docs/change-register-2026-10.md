# October 2026 change and validation register

Retrospective record; historical implementation dates are not invented where unavailable. Owner Joey; assistant Niko.

| Activity | State | Detailed record |
| --- | --- | --- |
| pfSense network, aliases, scoped access and broad-rule disablement | Implemented; selected historical traffic tests verified; post-reboot regression pending | [Firewall policy and aliases](firewall-policy-and-aliases.md) |
| Wazuh DC Defender channel | Implemented; new event pairs verified in dashboard | [Defender validation](defender-telemetry-validation-2026-10-08.md) |
| Victim scanner-only SMB rule and RemoteRegistry preparation | TCP445 and direct SMB/ADMIN$ access verified; scanner LSC validation pending; rollback documented, not executed | [Windows build and rollback](build-windows-endpoint-scan-readiness.md) |
| Wazuh/ELK queries and operational diagnostics | Recorded and reconstructed examples explicitly separated | [Query register](operations-query-register.md) |
| OpenVAS current feeds and service readiness | Verified; repeat two-host scan in progress at latest user update | [Baseline](soc-baseline-2026-10-08.md) |
| Recovery worksheet and reference | Document complete; unresolved tests tracked | [Recovery reference](recovery-runbook-reference.md) |
| Learning/notebook organization | Connector access and formatting verified | [Learning plan](learning-and-notebook-plan.md) |

## Publication audit
On October 8 the local checkout was nine commits ahead of the locally recorded origin/main. This comparison used the existing remote-tracking ref; a fresh remote fetch was not performed. Local commit creation does not publish a change to GitHub. The earlier index still described an allow-all firewall and was stale.

Recent local documents contain personal notebook links, local filesystem paths and course/career information. Review visibility and remove unintended personal references before publishing to a public repository. Raw firewall backups and credentials must remain private. No public push performed by this audit.

## Remaining reconstruction gaps
Exact final ordered pfSense rules and some alias UI spelling need private-export reconciliation. Recent exact ELK searches not retained must remain labeled reconstructed. Hunt002 needs a fuller source-linked case record. Scanner authentication, errors and findings must be assessed from the final repeated-scan report. Documentation maturity is not a declaration that every operational test passed.

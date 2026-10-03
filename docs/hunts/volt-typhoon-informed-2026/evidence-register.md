# Public evidence register

**TLP:CLEAR** | SOC-HUNT-2026-001 | October 3, 2026

The analysis used user-supplied screenshots, PowerShell and Linux output, Windows event XML, Task Scheduler text, and Splunk CSV exports. The local case package preserves 33 available evidence files with verified SHA-256 checksums and records 35 unavailable attachment paths. Checksums establish preservation integrity, not pre-collection chain of custody.

The parsed analysis covers 626 process events with command lines, 7,846 firewall log rows, 19 logon/explicit-credential rows, and 212 task changes across 20 task paths. Firewall rows are packet observations and can represent the same flow on multiple interfaces.

Original attachments, full checksum manifests, and derived CSVs are retained in the local case package. This public release contains report documents and diagrams. Evidence filenames referenced in the command log identify the original exports, but do not link to public raw files. Missing evidence, reconstructed commands, and limits on negative findings are documented in the technical report.

See the [technical report](technical-report.md) and [command log](command-query-log.md) for evidence-to-finding references and observed results.

# Changelog

All notable changes to this project are logged here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Reconciled — 2026-09-23

- Recorded Shuffle deployment, reboot execution, Wazuh webhooks, condition tests, scoped API account, automatic Windows marker response, and manual Shuffle reversal.
- Corrected current VM allocations, external SSD assumptions, pod memory budgets, and direct Wazuh-to-Shuffle response architecture.
- Updated Step 3.9 and evidence-backed checklist items while retaining Phase 4 attack tests and hardening as pending.
- Added sanitized marker scripts and a reproducibility/evidence checklist; no live credentials or workflow tokens are included.

### Added

- Initial repository scaffold: MkDocs documentation site, CI/CD pipeline (lint + link check + GitHub Pages deploy), configs/ and screenshots/ directories.
- Phase 1–6 Waterfall project plan documented under `docs/`.
- Docker Compose starters for OpenVAS/Greenbone and TheHive + Cortex under `configs/docker-compose/`.
- Network zone diagram (`docs/assets/network-zone-diagram.svg`) embedded in Phase 2 docs.
- CI pipeline now validates docker-compose syntax and scans for accidentally committed secrets (gitleaks).
- `GETTING_STARTED.md` — zero-experience walkthrough for GitHub Desktop, VS Code/Copilot, and the CI/CD pipeline.
- README updated to reference actual local path (`E:\PePesLab-SOC 2.0\soc-home-lab`).

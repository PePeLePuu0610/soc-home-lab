# Changelog

All notable changes to this project are logged here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- GInitial repository scaffold: MkDocs documentation site, CI/CD pipeline (lint + link check + GitHub Pages deploy), configs/ and screenshots/ directories.
- Phase 1–6 Waterfall project plan documented under `docs/`.
- Docker Compose starters for OpenVAS/Greenbone and TheHive + Cortex under `configs/docker-compose/`.
- Network zone diagram (`docs/assets/network-zone-diagram.svg`) embedded in Phase 2 docs.
- CI pipeline now validates docker-compose syntax and scans for accidentally committed secrets (gitleaks).
- `GETTING_STARTED.md` — zero-experience walkthrough for GitHub Desktop, VS Code/Copilot, and the CI/CD pipeline.
- README updated to reference actual local path (`E:\PePesLab-SOC 2.0\soc-home-lab`).

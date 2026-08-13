# Home SOC Lab

[![Docs CI](https://github.com/PePeLePuu0610/soc-home-lab/actions/workflows/docs-ci.yml/badge.svg)](https://github.com/PePeLePuu0610/soc-home-lab/actions/workflows/docs-ci.yml)
[![Docs Deploy](https://github.com/PePeLePuu0610/soc-home-lab/actions/workflows/docs-deploy.yml/badge.svg)](https://github.com/PePeLePuu0610/soc-home-lab/actions/workflows/docs-deploy.yml)

A Security Operations Center (SOC) home lab built end-to-end on a single Windows host with VMware Workstation Pro, using free and open-source tooling to simulate a real enterprise detection-and-response environment.

**Live documentation site:** <https://PePeLePuu0610.github.io/soc-home-lab/>

**New to GitHub or CI/CD?** Start with [`GETTING_STARTED.md`](GETTING_STARTED.md) — a full step-by-step walkthrough assuming zero prior experience.

## What's in this lab

- **pfSense** — firewall/router segmenting the lab into Management, Corporate, and Attacker network zones
- **Elastic Stack (ELK)** and **Splunk Enterprise** — two SIEMs, run side by side for comparison
- **Wazuh** — host-based intrusion detection (HIDS) / XDR
- **Suricata** — network intrusion detection (IDS)
- **OpenVAS (Greenbone)** — vulnerability scanning
- **SOAR** (TheHive + Cortex, or Shuffle) — automated response playbooks
- **Kali Linux** — attacker VM used to generate real detectable traffic
- **Windows Server (AD) + Windows 10/11** — simulated corporate target environment

## Project methodology

Built using **Waterfall** project management — Requirements → Design → Implementation → Testing → Deployment → Maintenance — with a sign-off checklist at the end of every phase. Full write-up is in [`docs/`](docs/) and published at the link above.

## Repository structure

```markdown
```text
soc-home-lab/
├── docs/                        # Full project documentation (MkDocs site, published via GitHub Pages)
│   └── assets/                  # Diagrams and other images referenced from docs pages
├── configs/
│   ├── pfsense/                 # Exported pfSense firewall rule sets
│   ├── wazuh/                   # Custom Wazuh rules/decoders
│   ├── suricata/                # Custom Suricata rule files
│   └── docker-compose/
│       ├── openvas/             # Greenbone/OpenVAS starter stack
│       └── thehive/              # TheHive + Cortex (SOAR) starter stack
├── screenshots/                  # Portfolio evidence: dashboards, alerts, playbook runs
├── mkdocs.yml                    # Docs site configuration
├── requirements.txt               # Python deps for building the docs site
└── .github/workflows/              # CI/CD pipeline (see below)
```markdown
```text

## CI/CD Pipeline

This repo uses two GitHub Actions workflows:

| Workflow | Trigger | What it does |
|---|---|---|
| `docs-ci.yml` | Every push and pull request | Lints all Markdown, checks for broken links, does a strict MkDocs build, validates every `docker-compose.yml` under `configs/`, and scans the whole repo for accidentally committed secrets — nothing is published, this is validation only |
| `docs-deploy.yml` | Push to `main` | Builds the MkDocs site and publishes it to the `gh-pages` branch, which GitHub Pages serves live |

In short: **CI** gate-checks every change (docs *and* configs), **CD** ships the docs site automatically once a change lands on `main`. No manual "build and upload" step required.

## GLocal development

This repo lives locally at:
```markdown
```text
E:\PePesLab-SOC 2.0\soc-home-lab
```markdown
```text

VM disks are stored separately and are **not** part of this repo:

```markdown
```text
E:\PePesLab-SOC 2.0\VMz
```

Keeping them apart matters — git chokes on multi-gigabyte `.vmdk` files, and GitHub has file-size limits that will silently fail a push if VM disks ever end up staged. Point VMware's default VM location at `VMz` once under **Edit → Preferences → Workspace** and every new VM lands there automatically.

To preview the docs site before pushing (from a terminal open in the repo folder — VS Code's integrated terminal, or PowerShell after `cd "E:\PePesLab-SOC 2.0\soc-home-lab"`):

```bash
pip install -r requirements.txt
mkdocs serve
```

Then open `http://127.0.0.1:8000` in a browser to preview.

This repo is edited locally in **VS Code** (with GitHub Copilot enabled) and committed/pushed via **GitHub Desktop**, both pointed at the folder above.

## License

[MIT](LICENSE) — this is a personal lab/portfolio project; use anything here as a reference for your own build.

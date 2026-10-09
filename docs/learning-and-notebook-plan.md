# Learning and notebook plan

Planning date: October 8, 2026. Owner: Joey. Status: both OneNote notebooks and their planned sections are verified through the connector; calendar entries have not been created. The Learning notebook is returned as Learning _ Career. The SOC baseline is maintained under 07 Portfolio and Consulting, with a navigation page in 00 Start Here. See [SOC baseline](soc-baseline-2026-10-08.md).

## Executive summary

Use a fresh project notebook, PePesLab SOC 2.0, and a separate Learning & Career notebook. Git remains authoritative. OneNote holds observations, drafts, learning notes, and daily reviews linked to Git. Calendar holds time commitments; a task board holds actionable work.

## SOC notebook structure

| Section | Initial pages |
| --- | --- |
| 00 Start Here | Project overview; current status; repository and dashboard links; working agreement |
| 01 Plan & Decisions | Milestones; weekly priorities; decision notes; risks and blockers |
| 02 Architecture | Topology; asset inventory; data flows; firewall policy overview |
| 03 Build & Changes | pfSense segmentation; alias cleanup; Wazuh integration; OpenVAS feeds |
| 04 Hunts & Validation | Hunt 001; Hunt 002; segmentation test matrix; scan validation; Defender telemetry |
| 05 Operations & Recovery | Backup and restore; startup checks; troubleshooting; runbook links |
| 06 Daily Journal | Dated pages with objectives, evidence, decisions, blockers, learning, and next actions |
| 07 Portfolio & Consulting | Case study drafts; lessons learned; consulting deliverable ideas |

Use YYYY-MM-DD - Topic page titles for dated work. Keep commands as selectable text. Link to reviewed Git documents and evidence files rather than attaching every raw export to multiple pages.

## Retrospective capture

Create a Baseline - 2026-10-08 page with historical event dates, source links, verification status, and limitations. This is retrospective documentation; do not invent contemporaneous notes or test results.

- pfSense: static WAN and gateway, scoped firewall exceptions, alias cleanup, disabled broad rules, local XML backup, tested allowed and blocked paths.
- Wazuh: both corporate agents reporting; DC Defender channel collection enabled and opened successfully. Delivery of a new Defender detection to Wazuh remains unverified.
- OpenVAS: two-host scan completed according to scanner logs; DC SMB authentication and registry access demonstrated in the partial export. Timeouts and Defender remediation limit coverage. Final report export still needs verification.
- Feeds: October 7-8 versions show Current; latest screenshot still displays syncing. Scan readiness remains pending banner clearance.
- Recovery: host failure required a reboot; user reports VMs and web interfaces restored. A full post-reboot control validation has not been performed.
- Threat hunts: preserve Hunt 001 and Hunt 002 source records and distinguish scanner output from firewall evidence.

Mark each entry Verified, Implemented - validation pending, or Open. Link to private evidence without publishing sensitive backups or credentials.

## Learning notebook structure

Sections: 00 Learning Roadmap; 01 AI Cybersecurity Leadership; 02 Content Creation & Planning; 03 AI Productivity; 04 Prompt & Workflow Library; 05 Credentials & Career Evidence.

Each course page records title, source link, progress, remaining modules, planned completion, actual completion, access limitations, personal notes, and one applied deliverable. On October 8, Joey confirmed none of the three planned specializations has been started and all are included in his existing subscription. No additional course purchase is planned. Completion targets remain provisional.

Joey's supplied Coursera coursework PDF establishes a completion record of 17 courses and the Google AI Professional Certificate. See [completed learning register](completed-learning-register.md) for titles, providers, completion months, evidence limitations, and applications. Public credential verification has not been performed.

## Course sequencing and applications

| Priority | Specialization | Applied output |
| --- | --- | --- |
| 1 | Generative AI Cybersecurity & Privacy for Leaders | SOC tabletop exercise and AI security/privacy checklist |
| 2 | ChatGPT: Master Free AI Tools to Supercharge Productivity | Reusable daily review and investigation-summary workflow |
| 3 | ChatGPT for Content Creation and Planning | Reviewed SOC case study and portfolio content plan; focus on material extending completed Google content and planning courses |

Coursework runs in parallel with SOC work, with one primary specialization active at a time. The cybersecurity and productivity programs list Prompt Engineering for ChatGPT and OpenAI GPTs in common. Track shared courses once; verify Coursera credit handling in Joey's enrollment before reducing completion estimates.

Sources:

- https://www.coursera.org/specializations/generative-ai-cybersecurity-leaders
- https://www.coursera.org/specializations/chatgpt-for-content-creation-planning
- https://www.coursera.org/specializations/chatgpt-free-ai-tools-to-excel
- https://support.microsoft.com/en-us/onenote/organize-your-notes

## Daily execution and calendar

Proposed ten-hour work allocation: two hours coursework; seven hours project implementation and validation; one hour notes, evidence promotion, and review. Breaks are additional to focused work blocks. Adjust from actual completion data.

Joey confirmed a usual start of 06:00 America/Denver and every day as a workday until further notice. Proposed schedule:

| Local time | Activity |
| --- | --- |
| 06:00-08:00 | Primary course study and exercises |
| 08:00-11:00 | SOC implementation and validation |
| 11:00-12:00 | Lunch and recovery break |
| 12:00-16:00 | SOC implementation, evidence analysis, and applied learning |
| 16:00-17:00 | Git documentation, OneNote review, and next-day priorities |

This represents ten planned work hours across an eleven-hour window. Additional short breaks may extend or reduce focused work; revise actual capacity accordingly. Use a lighter consolidation day for the weekly review when practical. Dates and appointments are not yet committed to a calendar.

Start each day with three intended outcomes. End with completed outcomes, evidence links, blockers, lessons, and tomorrow's priorities. Review milestones weekly and retain recovery time in estimates.

Calendar entries should use private appointments without attendees or invitations. External communication requires Joey's approval. Connection consent and task authority are separate. Calendar and Outlook connectors do not establish Microsoft To Do or Planner task creation capability; verify supported actions before choosing automation.

Before creating a schedule, confirm account connection, target calendar, start time, working days, and acceptable appointment scope. No account connection, invitations, tasks, or calendar events have been created as part of this plan.

## Success metrics and next actions

Success: working notes reference authoritative Git records; historical evidence is traceable; learning progress is recorded; each specialization produces a reviewed practical application; weekly plans reflect actual capacity and blockers.

Risks: duplicate documentation, interrupted coursework, unverified historical claims, and unsupported integration assumptions. Keep one source per record type and verify dependencies before scheduling delivery dates.

Completed: both notebooks and their planned sections are verified; the completed learning register is recorded in Git and formatted as native OneNote tables; the SOC retrospective baseline is recorded in Git and OneNote. Next actions: begin the cybersecurity specialization; verify feed readiness and post-recovery controls; connect the appropriate calendar capability and confirm the target calendar and private appointment scope.

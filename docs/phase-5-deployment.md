## PHASE 5 — Deployment / Go-Live

**Goal:** Move from "under construction" to "operational lab I use regularly."

1. Create VMware **snapshots** of every VM once it's in a known-good state — this lets you roll back instantly if an attack or misconfiguration breaks something (a real SOC equivalent of a backup).
2. Write yourself a one-page "power-on order" cheat sheet (pfSense first, then victims, then whichever SIEM/tool pod you're using that session) based on Section 1.3's pod strategy. **Update:** Pod A (pfSense, Windows victim, Wazuh) is now configured in VMware Workstation to AutoStart with the host — one less manual step each session, though it's still worth confirming all three came up cleanly after a host reboot before relying on the lab being "just on."
3. Document credentials and IPs somewhere safe (a local password manager, not a plain text file on the desktop).
4. **Harden pfSense before considering the lab "live."** During Phase 3 you likely loosened outbound rules on one or more zones so VMs could patch/update. Before go-live, walk back through every zone and tighten:
   - **Attacker zone:** should only be able to reach the Corp zone (to simulate an external attacker) and, if you want Kali itself to stay patched, a narrow outbound-only allowance for updates — it should *not* be able to reach Management.
   - **Corp zone:** should reach Management only on the specific ports your agents/tools need (e.g., Wazuh agent port, Suricata/log forwarding ports), not "any."
   - **Management zone:** can stay permissive outbound since it's your own tooling, but should not be reachable *from* the Attacker zone at all.
   - Remove any temporary "allow any outbound" rules you added per-VM during building/patching in Phase 3.
   - **Confirm:** rerun the Phase 4 network isolation test after hardening to make sure tightening the rules didn't also break log forwarding or agent connectivity.

### Exit Criteria for Phase 5

- [ ] Snapshots taken of all VMs
- [ ] Power-on cheat sheet written
- [ ] Credentials stored securely
- [ ] Temporary "build-phase" firewall rules removed and permanent hardened rules in place
- [ ] Phase 4 isolation test re-run successfully after hardening

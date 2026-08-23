# Build Guide: ELK Stack VM (Step 3.6)

**VM name:** `SOC-SIEM-ELK` · **Zone:** Management · **IP:** `10.10.10.10` · **Specs:** 8GB RAM / 2 vCPU / 60GB disk

This guide covers building the ELK Stack (Elasticsearch, Logstash, Kibana) VM from your Ubuntu 22.04 LTS template, as part of [Phase 3 — Implementation](phase-3-implementation.md). Commands were verified against Elastic's current official documentation (Elastic Stack 9.x) rather than older tutorials, since package repos and default security behavior have changed across major versions.

## Before you start

Both SIEM VMs (this one and Splunk) sit on the Management zone alongside Wazuh, so traffic between them never crosses pfSense — it's direct host-to-host on the same subnet. Traffic *into* this VM from the Corp zone (e.g. later log forwarding from the Windows victim) does cross pfSense, and is already covered by the temporary "allow any" rule on the Corp interface from the pfSense build step. Since Management is a Host-only network, you can browse Kibana directly from a browser on your physical Windows host — no port forwarding needed.

## 3.6.1 — Clone the VM

1. In VMware Workstation, right-click your Ubuntu 22.04 LTS template → **Manage → Clone**.
2. Choose **Create a full clone** (not linked — you want this VM independent of the template going forward).
3. Name it `SOC-SIEM-ELK`, location `E:\PePesLab-SOC 2.0\VMz\SOC-SIEM-ELK`.
4. Edit VM settings: **Memory → 8192 MB**, **Processors → 2**, **Network Adapter → Custom: VMnet1 (Management)**.
5. Power on and log in.

## 3.6.2 — Configure networking and update the OS

Edit your netplan config (filename may differ slightly — check `ls /etc/netplan/`):

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens160:
      dhcp4: no
      addresses: [10.10.10.10/24]
      routes:
        - to: default
          via: 10.10.10.5
      nameservers:
        addresses: [10.10.10.5]
```

```bash
sudo netplan apply
sudo hostnamectl set-hostname SOC-SIEM-ELK
ping -c 3 10.10.10.5        # confirm pfSense is reachable
ping -c 3 8.8.8.8           # confirm outbound internet works
sudo apt update && sudo apt upgrade -y
```

## 3.6.3 — Install Elasticsearch

```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list
sudo apt update
sudo apt install elasticsearch -y
```

**Read the install output carefully** — it prints something like:

```text
Authentication and authorization are enabled.
TLS for the transport and HTTP layers is enabled and configured.
The generated password for the elastic built-in superuser is : xxxxxxxxxxxx
```

**Write that password down now** — it's shown exactly once. No separate Java install is needed; modern Elasticsearch bundles its own JDK.

```bash
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
sudo systemctl status elasticsearch      # confirm "active (running)"
curl -k -u elastic:<your-password> https://10.10.10.10:9200
```

That last command should return a JSON block with `"cluster_name"` and the tagline `"You Know, for Search"` — confirmation Elasticsearch is alive.

## 3.6.4 — Install Kibana

```bash
sudo apt install kibana -y
sudo nano /etc/kibana/kibana.yml
```

Set `server.host: "0.0.0.0"` and confirm `server.port: 5601`.

```bash
sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
```

Copy the token this prints, then:

```bash
sudo /usr/share/kibana/bin/kibana-setup --enrollment-token <paste-token-here>
```

This token is only valid 30 minutes — if it expires, just regenerate it.

```bash
sudo systemctl enable kibana
sudo systemctl start kibana
sudo journalctl -u kibana -f
```

Watch that log output — on first browser visit it shows a **verification code**. Open `http://10.10.10.10:5601` **from your Windows host browser** (not `localhost` — that points at your own machine, not the VM), enter the code when prompted, then log in with username `elastic` and the password from 3.6.3.

Once logged in, create a named personal admin account (search bar → type `Users` → **Create user**, assign the `superuser` role) rather than using `elastic` day to day, the same principle as not living in `root` on the Linux side.

## 3.6.5 — Install Logstash

```bash
sudo apt install logstash -y
sudo nano /etc/logstash/conf.d/beats-to-es.conf
```

```text
input {
  beats {
    port => 5044
  }
}
output {
  elasticsearch {
    hosts => ["https://10.10.10.10:9200"]
    user => "elastic"
    password => "<your-password>"
    ssl_certificate_verification => false
    index => "soc-lab-%{+YYYY.MM.dd}"
  }
}
```

```bash
sudo systemctl enable logstash
sudo systemctl start logstash
sudo ss -tunlp | grep 5044      # confirm Logstash is listening for Beats input
```

## 3.6.6 — Snapshot and sign off

In VMware: **VM → Snapshot → Take Snapshot** → name it `ELK working baseline`.

### Exit criteria for Step 3.6

- [ ] VM built, static IP `10.10.10.10`, hostname set
- [ ] Elasticsearch running, `curl` returns cluster info
- [ ] Kibana reachable at `http://10.10.10.10:5601`, login successful
- [ ] Named personal admin user created (not just `elastic`)
- [ ] Logstash listening on port 5044
- [ ] Snapshot taken

## Troubleshooting: setup wizard stuck on "Completing setup"

If Kibana's onboarding wizard hangs indefinitely after saving settings, work through these in order before assuming something's broken:

1. **Confirm you're browsing the VM's actual IP, not `localhost`** — the most common cause of this exact symptom.
2. `df -h` — a disk above ~85-90% full puts Elasticsearch into read-only mode, silently blocking Kibana's setup.
3. `curl -k -u elastic:<password> https://10.10.10.10:9200/_cluster/health?pretty` — `yellow` is normal for a single-node cluster; `red` means something's actually broken.
4. `sudo journalctl -u kibana -n 200 --no-pager` — the wizard hides the real error from you; it's in here.
5. `sudo systemctl status elasticsearch` and `sudo systemctl status kibana` — both should read `active (running)`.
6. If still stuck: `sudo systemctl restart elasticsearch`, wait ~30s and recheck health, then `sudo systemctl restart kibana`.
7. Last resort (destructive to Kibana's config, not your log data): stop kibana, `curl -k -u elastic:<password> -X DELETE "https://10.10.10.10:9200/.kibana*"`, generate a fresh enrollment token, and re-run `kibana-setup`.

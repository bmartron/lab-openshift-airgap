# Changelog

## [Unreleased]

### Docs (versions — BPG provider)
- [architecture/versions.md](architecture/versions.md): stack table uses **bpg/proxmox ~> 0.85** (not Telmate)

### Docs (reorg — official Day 0/1/2)
- Split under `docs/deploy/`, `docs/architecture/`, `docs/faq/`
- DAY checklists use Red Hat Day definitions; FAQ aggregator at [faq/README.md](faq/README.md)
- Slimmed [ansible/README.md](../ansible/README.md) and [bastion/README.md](../bastion/README.md)

### Docs (human path)
- Added [DAY0.md](deploy/DAY0.md) / [DAY1.md](deploy/DAY1.md) / [DAY2.md](deploy/DAY2.md) / [FAQ.md](faq/FAQ.md) + [docs/README.md](README.md) index
- Root [README.md](../README.md) slimmed to a hub pointing at Day docs

### Docs (Day-2 Virt / LVMS / guest boots — lab-validated)
- [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) § Day-2 — order: disks at Terraform create → LVMS sub → **LVMCluster** → Virt → guest_boots; console project filter for bootable volumes
- [docs/deploy/openshift-virt-lab.md](deploy/openshift-virt-lab.md) — disk by-path map, DataSource Ready checks, Bootable volumes UI tip
- [README.md](../README.md) Day-2 table aligned; guest boots marked validated on compact3

### Removed (lab scope)
- Dropped OpenShift **5 RC** / Assisted connected track: `openshift/5-rc/`, `terraform/assisted-ocp-bma/`, `mirror/imageset-config-5-rc.yaml.example`
- Removed ocp5 DNS records from Ansible `dns` role and examples
- READMEs focused on **4.22 GA air-gap SNO** only (English)

### Fixed (registry reboot)
- Registry role enables `podman-restart.service` (lab-verified: without it, `ocp-registry` stays Exited after VM reboot)

### Docs (rebuild)
- [docs/deploy/iac.md](deploy/iac.md) — after Terraform: `ssh_public_key_file`, `ssh-keygen -R` lab IPs, verify bastion SSH before Ansible
- [docs/deploy/ansible-ocp-install.md](deploy/ansible-ocp-install.md) — rewritten: happy path (mandatory) vs optional workarounds

### Added (lab SSH trust playbook)
- `ansible/playbooks/lab-ssh.yml` — bastion key → dns/registry + Proxmox; `ssh-keygen -R` on bastion for lab IPs
- Imported by `lab-infra.yml` and `bastion-ocp-install.yml` for repeat rebuilds

### Fixed (bastion → dns/registry SSH)
- `lab-infra.yml` installs bastion `~/.ssh/id_ed25519.pub` into `bernard` authorized_keys on dns/registry (cloud-init only had the Mac key)

### Changed (SNO rootDeviceHints)
- Default install disk hint: `/dev/disk/by-path/pci-0000:06:0a.0` (Proxmox virtio0 / 120G) instead of `/dev/vda` — multi-disk agent matching

### Changed (SNO sshKey)
- `bastion-ocp-install` embeds the **live** bastion `~/.ssh/id_ed25519.pub` into install-config (no Mac `install_ssh_key.pub`) — [proxmox/access.md](../proxmox/access.md)

### Ajouté (Ansible install OCP bastion)
- Playbook `ansible/playbooks/bastion-ocp-install.yml` + rôle `ocp_bastion_install` (install-config, agent-config, imageset, CA, pull-secret)
- [docs/deploy/ansible-ocp-install.md](deploy/ansible-ocp-install.md) — procédure mise à jour configs sans YAML manuel
- Bastion scripts kept: `pull-secret-for-oc-mirror.sh`, `lab-startup-check.sh`, `verify-mirror-before-sno.sh` (install-config helpers removed — use Ansible)

### Corrigé (alignement doc)
- Stack alignment (versions provider, commandes obsolètes) fusionné dans [docs/architecture/versions.md](architecture/versions.md)
- Docs recovery/parity/teardown registry retirés — rebuild via [docs/deploy/iac.md](deploy/iac.md) + [terraform/README.md](../terraform/README.md)
- Harmonisation **`oc-mirror`** dans README / bastion / mirror / registry / 5-rc
- [mirror/imageset-config-5-rc.yaml.example](../mirror/imageset-config-5-rc.yaml.example) — GitOps épinglé

### Corrigé (IaC / doc alignement lab)
- Terraform : **telmate/proxmox 3.0.2-rc10** (Proxmox VE 9 — plus de check `VM.Monitor`)
- `vms.tf` : schéma provider 3.x (`network.id`, `iothread` bool, ISO sur disque `ide2`)
- [mirror/README.md](../mirror/README.md) : `oc-mirror` + `--authfile` (pas `oc mirror` / `--src-pull-secret`)

### Ajouté (IaC lab)
- [terraform/](../terraform/) — VMs Proxmox (registry clone : virtio0 + virtio1 /dev/vdb)
- [ansible/](../ansible/) — playbooks DNS / registry / bastion
- [docs/deploy/iac.md](deploy/iac.md) — parcours lab existant vs greenfield

### Ajouté (coupure quotidienne lab)
- [docs/deploy/lab-power-cycle.md](deploy/lab-power-cycle.md) — arrêt/démarrage ordonné, NTP, dépannage SNO
- [bastion/scripts/lab-startup-check.sh](../bastion/scripts/lab-startup-check.sh) — prérequis avant boot SNO (DNS, registry, NTP)
- [dns/README.md](../dns/README.md) — drop-in systemd dnsmasq au reboot

### Ajouté
- Structure initiale du dépôt lab OpenShift air-gap
- Documentation architecture et réseau
- Exemples de configuration (install-config, agent-config, dnsmasq, registry)
- Procédure miroir des images
- Guide création bridge `vmbr1` (contrainte nommage Proxmox)
- Guide déploiement VM DNS (`dns/README.md`)
- RHEL 10 pour toutes les VMs infra
- Double piste OpenShift : GA 4.22.12 + RC 5.0.0-ec.6
- Configs versionnées : `openshift/4.22-ga/`, `openshift/5-rc/`
- `versions.env.example`, `docs/architecture/versions.md`, `bastion/README.md`

### Ajouté (session DNS / accès lab)
- [rhel/dvd-repo.md](../rhel/dvd-repo.md) — repo local DVD sans souscription
- [proxmox/access.md](../proxmox/access.md) — SSH via Proxmox, noVNC, shutdown
- [dns/README.md](../dns/README.md) — procédure complète VM DNS mise à jour
- Progression lab dans README principal

### Ajouté (accès lab / registry)
- Paramètres concrets : Proxmox `192.168.1.147`, user `bernard`, ProxyJump
- Procédure `scp` registry2.tar Mac → VM registry
- Repo DVD via `sudo tee` (correction `cp rhel-dvd.repo`)
- Podman Desktop + Podman Machine sur Mac documenté

### Ajouté (registry terminé + Proxmox hosts)
- Proxmox `/etc/hosts` pour noms lab — DNS maison inchangé ([proxmox/hosts.lab.example](../proxmox/hosts.lab.example))
- Registry : amd64, openssl, `--pull=never`, sudo podman load
- Bastion README complet — prochaine étape

### Corrigé (dnsmasq RHEL 10)
- `listen-address=172.16.10.11` — dnsmasq n'écoutait que sur localhost
- `firewall-cmd --add-service=dns` — requis pour requêtes depuis bastion/registry

### Ajouté (bastion DNS + mirror)
- [bastion/README.md](../bastion/README.md) — résolution DNS double NIC (`ipv4.ignore-auto-dns` sur `ens18`)
- `sudo` requis pour `nmcli con mod` ; `resolvectl` non applicable sur RHEL
- Trust CA registry (`/etc/containers/certs.d/` + `update-ca-trust`)
- [mirror/README.md](../mirror/README.md) — procédure `oc mirror` complète + dépannage TLS/DNS
- Progression bastion mise à jour (prochaine étape : `oc mirror`)

### Corrigé (registry TLS + bastion DNS)
- Certificat registry : ajout SAN (`subjectAltName`) requis par oc-mirror v2 / Go
- Bastion double NIC : `/etc/hosts` lab + DNS maison (Internet + lab coexistants)

### Ajouté (mirror + install agent GA 4.22.12)
- [mirror/README.md](../mirror/README.md) — procédure `oc mirror` v2 complète, vérification post-mirror, dépannage SAN/x509
- [bastion/README.md](../bastion/README.md) — `nmstate`, `xorriso`, `oc-mirror` v2, progression mise à jour
- [dns/README.md](../dns/README.md) — serveur NTP chrony lab + fuseau Europe/Paris
- [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) — workflow install complet, dépannage ISO, surveillance logs

### Corrigé (configs install GA 4.22.12)
- `install-config.yaml` : `baseDomain: lab.local` (pas `ocp422.lab.local`), bloc `networking` avec `machineNetwork: 172.16.10.0/24`
- `agent-config.yaml` : `apiVersion: v1beta1`, `additionalNTPSources`, `rendezvousIP`, `mac-address` dans networkConfig
- `rootDeviceHints` : Proxmox SCSI → `/dev/sda` (pas `/dev/vda`) ; chemins `by-id` non acceptés par l'installer
- Génération ISO : reset `.openshift_install_state.json` si état partiel ; prérequis `xorriso`
- Backup `config-backup/` avant `create image` (configs supprimées automatiquement)

### Ajouté (install SNO validée + réinstall)
- Install GA 4.22.12 SNO air-gap validée en lab (~30 min avec mirror existant)
- Removed `rhel/` docs folder — DVD repo covered in [ansible/README.md](../ansible/README.md) § RHEL DVD
- Removed empty `registry/` docs folder — registry VM documented in [ansible/README.md](../ansible/README.md)
- Slimmed `proxmox/` docs to Terraform+Ansible path (EN)
- [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) — post-install (`oc login`, OAuth `/etc/hosts`), faux timeout `wait-for`, réinstall
- Bastion `/etc/hosts` : `oauth-openshift` et `console-openshift-console`

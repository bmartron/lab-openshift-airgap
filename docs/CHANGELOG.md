# Changelog

## [Non publié]

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
- `versions.env.example`, `docs/versions.md`, `bastion/README.md`

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
- [proxmox/sno-vm.md](../proxmox/sno-vm.md) — detach disque, **Unused Disk**, réinstall sans recréer la VM
- [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) — post-install (`oc login`, OAuth `/etc/hosts`), faux timeout `wait-for`, réinstall
- Bastion `/etc/hosts` : `oauth-openshift` et `console-openshift-console`

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

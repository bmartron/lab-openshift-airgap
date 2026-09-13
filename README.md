# Lab OpenShift Air-Gap — Proxmox / NUC

Lab personnel pour se former à l'installation **agent-based** d'OpenShift en mode **déconnecté (air-gap)**, sur une plateforme **Proxmox** hébergée sur un NUC 15 Pro.

## Plateforme

| Composant | Détail |
|-----------|--------|
| Hôte | NUC 15 Pro — 64 Go RAM |
| Hyperviseur | Proxmox sur SSD externe 512 Go (USB) |
| Stockage VMs / ISO | NAS NFS |
| Mode boot | Proxmox sur SSD externe — Windows préservé sur disque interne 1 To |

## Objectifs

- [x] Installation **SNO** (Single Node OpenShift) en air-gap — GA 4.22.12 validée
- [ ] Installation **3 nœuds** (cluster compact) en air-gap
- [ ] OpenShift Virtualization (nested virt) — phase ultérieure

## Topologies réseau

| Bridge Proxmox | Rôle | Internet |
|----------------|------|----------|
| `vmbr0` | Admin / LAN maison | Oui |
| `vmbr1` | Lab OpenShift isolé | **Non** |

Plan d'adressage lab : `172.16.10.0/24` — voir [docs/network.md](docs/network.md).

## VMs du lab

| VM | Rôle | Réseau |
|----|------|--------|
| `bastion` | `oc`, `openshift-install`, orchestration | `vmbr0` + `vmbr1` |
| `dns` | Résolution interne (`dnsmasq`) | `vmbr1` uniquement |
| `registry` | Mirror registry (images OCP) | `vmbr1` uniquement |
| `ocp-sno` | Nœud OpenShift | `vmbr1` uniquement |

## Structure du dépôt

```
.
├── docs/                  # Architecture, réseau, versions, procédures
├── proxmox/               # Réseau, accès SSH, console
├── rhel/                  # Repo DVD local (sans souscription)
├── bastion/               # VM bastion RHEL 10
├── openshift/
│   ├── 4.22-ga/           # Config install GA (4.22.12)
│   └── 5-rc/              # Config install RC (5.0.0-ec.6)
├── dns/                   # Configuration DNS
├── registry/              # Mirror registry + TLS
├── mirror/                # Procédures oc-mirror (GA + Beta)
├── terraform/             # Proxmox (VMs lab)
├── ansible/               # Config DNS, registry, bastion
└── versions.env.example   # Variables de version (copier → versions.env)
```

## Démarrage rapide

1. Lire [docs/architecture.md](docs/architecture.md)
2. Configurer le bridge `vmbr1` — [proxmox/network.md](proxmox/network.md)
3. Accès SSH aux VMs isolées — [proxmox/access.md](proxmox/access.md)
4. Configs install SNO (install-config, agent-config, CA) — [docs/ansible-ocp-install.md](docs/ansible-ocp-install.md)
5. Repo RHEL via DVD (sans souscription) — [rhel/dvd-repo.md](rhel/dvd-repo.md)
6. Déployer DNS — [dns/README.md](dns/README.md) → registry → bastion
7. Miroir des images — [mirror/README.md](mirror/README.md)
8. Générer l'ISO agent et installer — [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md)
9. VM SNO Proxmox (disque, réinstall) — [proxmox/sno-vm.md](proxmox/sno-vm.md)
10. **Arrêt / démarrage quotidien** — [docs/lab-power-cycle.md](docs/lab-power-cycle.md) + script `bastion/scripts/lab-startup-check.sh`
11. **Terraform + Ansible** (optionnel) — [docs/iac.md](docs/iac.md)
12. **Alignement versions / audit** — [docs/lab-alignment.md](docs/lab-alignment.md)

## Progression lab

- [x] Proxmox + NFS + bridge `vmbr1`
- [x] VM DNS RHEL 10 — réseau `172.16.10.11`
- [x] Repo DVD local (sans subscription-manager)
- [x] dnsmasq opérationnel + tests `dig`
- [x] VM registry — HTTPS actif (`registry:2` amd64)
- [x] Proxmox `/etc/hosts` pour noms lab (DNS maison conservé)
- [x] VM bastion — réseau, `oc` / `openshift-install` / `oc-mirror` v2, DNS lab, CA registry
- [x] NTP lab (chrony sur DNS) + fuseau Europe/Paris
- [x] Mirror OCP 4.22.12 (`oc-mirror` v2 → ~22 Go)
- [x] Install SNO GA 4.22.12 (+ réinstall de contrôle ~30 min)
- [ ] Mirror OCP 5 RC + install SNO RC
- [ ] VM workstation graphique (console web, optionnel)

## Versions cibles

| Composant | Version | Statut |
|-----------|---------|--------|
| VMs infra (dns, registry, bastion) | **RHEL 10.2** | ✅ |
| OpenShift GA | **4.22.12** (Kubernetes 1.35) | ✅ SNO air-gap |
| OpenShift RC | **5.0.0-ec.6** (Kubernetes 1.36) | ⬜ |
| Proxmox | _à documenter_ | ⬜ |

Détail : [docs/versions.md](docs/versions.md)

## Notes

- Les secrets (`pull-secret`, clés, kubeconfig) sont exclus par `.gitignore`.
- Copier les fichiers `.example` vers leurs équivalents locaux avant utilisation.

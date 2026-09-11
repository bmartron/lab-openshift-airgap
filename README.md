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

- [ ] Installation **SNO** (Single Node OpenShift) en air-gap
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
├── mirror/                # Procédures oc mirror (GA + Beta)
└── versions.env.example   # Variables de version (copier → versions.env)
```

## Démarrage rapide

1. Lire [docs/architecture.md](docs/architecture.md)
2. Configurer le bridge `vmbr1` — [proxmox/network.md](proxmox/network.md)
3. Accès SSH aux VMs isolées — [proxmox/access.md](proxmox/access.md)
4. Repo RHEL via DVD (sans souscription) — [rhel/dvd-repo.md](rhel/dvd-repo.md)
5. Déployer DNS — [dns/README.md](dns/README.md) → registry → bastion
6. Miroir des images — [mirror/README.md](mirror/README.md)
7. Générer l'ISO agent et installer — [openshift/README.md](openshift/README.md)

## Progression lab

- [x] Proxmox + NFS + bridge `vmbr1`
- [x] VM DNS RHEL 10 — réseau `172.16.10.11`
- [x] Repo DVD local (sans subscription-manager)
- [x] dnsmasq opérationnel + tests `dig`
- [ ] VM registry (en cours — image registry:2 transférée)
- [ ] VM bastion
- [ ] Mirror OCP 4.22.12 + install SNO GA
- [ ] Mirror OCP 5 RC + install SNO RC

## Versions cibles

| Composant | Version | Statut |
|-----------|---------|--------|
| VMs infra (dns, registry, bastion) | **RHEL 10.2** | 🔄 DNS en cours |
| OpenShift GA | **4.22.12** (Kubernetes 1.35) | ⬜ |
| OpenShift RC | **5.0.0-ec.6** (Kubernetes 1.36) | ⬜ |
| Proxmox | _à documenter_ | ⬜ |

Détail : [docs/versions.md](docs/versions.md)

## Notes

- Les secrets (`pull-secret`, clés, kubeconfig) sont exclus par `.gitignore`.
- Copier les fichiers `.example` vers leurs équivalents locaux avant utilisation.

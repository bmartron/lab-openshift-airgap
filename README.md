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
| `vmbr-lab` | Lab OpenShift isolé | **Non** |

Plan d'adressage lab : `172.16.10.0/24` — voir [docs/network.md](docs/network.md).

## VMs du lab

| VM | Rôle | Réseau |
|----|------|--------|
| `bastion` | `oc`, `openshift-install`, orchestration | `vmbr0` + `vmbr-lab` |
| `dns` | Résolution interne (`dnsmasq`) | `vmbr-lab` uniquement |
| `registry` | Mirror registry (images OCP) | `vmbr-lab` uniquement |
| `ocp-sno` | Nœud OpenShift | `vmbr-lab` uniquement |

## Structure du dépôt

```
.
├── docs/                  # Architecture, réseau, procédures
├── proxmox/               # Notes et scripts Proxmox
├── openshift/             # install-config, agent-config (exemples)
├── dns/                   # Configuration DNS
├── registry/              # Mirror registry + TLS
└── mirror/                # Procédures oc mirror
```

## Démarrage rapide

1. Lire [docs/architecture.md](docs/architecture.md)
2. Configurer le bridge `vmbr-lab` sur Proxmox — [proxmox/network.md](proxmox/network.md)
3. Déployer DNS, registry, bastion
4. Miroir des images — [mirror/README.md](mirror/README.md)
5. Générer l'ISO agent et installer — [openshift/README.md](openshift/README.md)

## Versions cibles

| Composant | Version | Statut |
|-----------|---------|--------|
| OpenShift | _à définir_ | ⬜ |
| Proxmox | _à définir_ | ⬜ |

## Notes

- Les secrets (`pull-secret`, clés, kubeconfig) sont exclus par `.gitignore`.
- Copier les fichiers `.example` vers leurs équivalents locaux avant utilisation.

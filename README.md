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
├── proxmox/               # Notes et scripts Proxmox
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
2. Configurer le bridge `vmbr1` sur Proxmox — [proxmox/network.md](proxmox/network.md)
3. Déployer DNS, registry, bastion
4. Miroir des images — [mirror/README.md](mirror/README.md)
5. Générer l'ISO agent et installer — [openshift/README.md](openshift/README.md)

## Versions cibles

| Composant | Version | Statut |
|-----------|---------|--------|
| VMs infra (dns, registry, bastion) | **RHEL 10.2** | ⬜ |
| OpenShift GA | **4.22.12** (Kubernetes 1.35) | ⬜ |
| OpenShift RC | **5.0.0-ec.6** (Kubernetes 1.36) | ⬜ |
| Proxmox | _à documenter_ | ⬜ |

Détail : [docs/versions.md](docs/versions.md)

## Notes

- Les secrets (`pull-secret`, clés, kubeconfig) sont exclus par `.gitignore`.
- Copier les fichiers `.example` vers leurs équivalents locaux avant utilisation.

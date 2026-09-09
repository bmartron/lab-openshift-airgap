# Plan réseau

## Bridges Proxmox

### vmbr0 — Admin / LAN maison

- Connecté au réseau physique du NUC.
- Proxmox, accès NAS NFS, bastion `eth0` (phase préparation).

### vmbr1 — Lab air-gap

- Bridge **virtuel** sans interface physique.
- **Aucune passerelle** vers Internet.
- Toutes les VMs du cluster OpenShift.

## Plan d'adressage — `172.16.10.0/24`

| Hostname | IP | Rôle |
|----------|-----|------|
| `proxmox.lab.local` | `172.16.10.1` | Gateway lab (optionnel, debug depuis l'hôte) |
| `bastion.lab.local` | `172.16.10.10` | Bastion — interface lab |
| `dns.lab.local` | `172.16.10.11` | Serveur DNS |
| `registry.lab.local` | `172.16.10.20` | Mirror registry |
| `ocp-sno-422.lab.local` | `172.16.10.100` | SNO OpenShift 4.22 GA |
| `ocp-sno-5.lab.local` | `172.16.10.110` | SNO OpenShift 5 RC |

### Enregistrements DNS OpenShift 4.22 GA

| FQDN | IP | Notes |
|------|-----|-------|
| `api.ocp422.lab.local` | `172.16.10.100` | API Kubernetes |
| `api-int.ocp422.lab.local` | `172.16.10.100` | API interne |
| `*.apps.ocp422.lab.local` | `172.16.10.100` | Wildcard ingress |

### Enregistrements DNS OpenShift 5 RC

| FQDN | IP | Notes |
|------|-----|-------|
| `api.ocp5.lab.local` | `172.16.10.110` | API Kubernetes |
| `api-int.ocp5.lab.local` | `172.16.10.110` | API interne |
| `*.apps.ocp5.lab.local` | `172.16.10.110` | Wildcard ingress |

### Cluster 3 nœuds (futur)

| Hostname | IP |
|----------|-----|
| `master0.ocp.lab.local` | `172.16.10.101` |
| `master1.ocp.lab.local` | `172.16.10.102` |
| `master2.ocp.lab.local` | `172.16.10.103` |

## Matrice de connectivité

| VM | vmbr0 (Internet) | vmbr1 | Parle à |
|----|------------------|----------|---------|
| bastion | Oui (`eth0`) | Oui (`eth1`) | tout le lab |
| dns | Non | Oui | résolution pour tout le lab |
| registry | Non | Oui | bastion + nœuds OCP |
| nœuds OCP | Non | Oui | dns + registry |

## Simulation air-gap stricte

Après la phase de préparation :

- Désactiver `eth0` sur la bastion, ou
- Supprimer la route par défaut vers Internet, ou
- Filtrer au firewall — aucun trafic sortant depuis `172.16.10.0/24`.

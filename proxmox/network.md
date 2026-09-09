# Configuration réseau Proxmox

## Noms de bridges

Proxmox **n'accepte pas le tiret** (`-`) dans les noms d'interfaces. Utiliser :

| Bridge | Rôle |
|--------|------|
| `vmbr0` | Admin / LAN maison (existant) |
| `vmbr1` | Lab OpenShift air-gap (isolé) |

## Bridge lab isolé (`vmbr1`)

Via l'UI Proxmox → **System → Network → Create → Linux Bridge** :

| Champ | Valeur |
|-------|--------|
| Name | `vmbr1` |
| IPv4/CIDR | `172.16.10.1/24` |
| Gateway | *(vide)* |
| Bridge ports | *(vide — aucune interface physique)* |

Ou ajouter dans `/etc/network/interfaces` :

```text
auto vmbr1
iface vmbr1 inet static
    address 172.16.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Appliquer :

```bash
ifreload -a
```

## Règles

- **Ne pas** ajouter de `gateway` sur `vmbr1`.
- **Ne pas** configurer NAT depuis `172.16.10.0/24` vers Internet.
- VMs OpenShift, DNS, registry : **une seule NIC** sur `vmbr1`.
- Bastion : `eth0` → `vmbr0`, `eth1` → `vmbr1`.

## Stockage NFS

- ISO et disques VM sur le datastore NFS Proxmox.
- Cache disque VM recommandé : `none` ou `directsync` (éviter `writeback` sur NFS).

## Nested virtualization (phase OpenShift Virtualization)

Sur chaque VM hôte OpenShift :

- Type CPU : **host**
- Activer nested virt sur l'hôte Proxmox si nécessaire.

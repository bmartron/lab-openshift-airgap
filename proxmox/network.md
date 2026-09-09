# Configuration réseau Proxmox

## Bridge lab isolé

Ajouter dans `/etc/network/interfaces` (ou via l'UI Proxmox → System → Network) :

```text
auto vmbr-lab
iface vmbr-lab inet static
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

- **Ne pas** ajouter de `gateway` sur `vmbr-lab`.
- **Ne pas** configurer NAT depuis `172.16.10.0/24` vers Internet.
- VMs OpenShift, DNS, registry : **une seule NIC** sur `vmbr-lab`.
- Bastion : `eth0` → `vmbr0`, `eth1` → `vmbr-lab`.

## Stockage NFS

- ISO et disques VM sur le datastore NFS Proxmox.
- Cache disque VM recommandé : `none` ou `directsync` (éviter `writeback` sur NFS).

## Nested virtualization (phase OpenShift Virtualization)

Sur chaque VM hôte OpenShift :

- Type CPU : **host**
- Activer nested virt sur l'hôte Proxmox si nécessaire.

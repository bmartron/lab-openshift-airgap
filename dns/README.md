# VM DNS — `dns.lab.local`

Serveur DNS interne du lab air-gap. Résolution locale uniquement (pas d'upstream Internet).

## Spécifications VM (Proxmox)

| Paramètre | Valeur |
|-----------|--------|
| Nom | `dns` |
| OS | **RHEL 10** (minimal) |
| vCPU | 1 |
| RAM | 1 Go |
| Disque | 10 Go (NFS) |
| NIC | 1 × `vmbr1` |
| IP | `172.16.10.11/24` |
| Gateway | `172.16.10.1` |
| Hostname | `dns.lab.local` |

## 1. Créer la VM dans Proxmox

1. **Create VM** → VM ID libre (ex. `110`)
2. **OS** : ISO RHEL/Rocky/Alma (depuis datastore NFS)
3. **System** : défaut (BIOS ou UEFI selon ISO)
4. **Disks** : 10 Go, storage NFS, cache `none`
5. **CPU** : 1 core
6. **Memory** : 1024 Mo
7. **Network** :
   - Bridge : **`vmbr1`**
   - Model : VirtIO
   - **Pas de firewall** Proxmox sur cette NIC (pour l'instant)
8. Installer l'OS — installation minimale suffit

## 2. Réseau statique (RHEL 10 — nmcli)

Sur la VM, identifier l'interface (souvent `ens18` ou `enp6s18`) :

```bash
nmcli device status
```

```bash
NM_DEV=ens18   # adapter

nmcli con mod "$NM_DEV" ipv4.addresses 172.16.10.11/24
nmcli con mod "$NM_DEV" ipv4.gateway 172.16.10.1
nmcli con mod "$NM_DEV" ipv4.dns 127.0.0.1
nmcli con mod "$NM_DEV" ipv4.method manual
nmcli con mod "$NM_DEV" ipv6.method ignore
nmcli con up "$NM_DEV"

hostnamectl set-hostname dns.lab.local
```

Vérifier depuis **Proxmox** :

```bash
ping -c 2 172.16.10.11
```

## 3. Installer dnsmasq

```bash
sudo dnf install -y dnsmasq
sudo systemctl stop systemd-resolved 2>/dev/null || true
sudo systemctl disable systemd-resolved 2>/dev/null || true
```

> Si `systemd-resolved` écoute sur le port 53, le désactiver avant de démarrer dnsmasq.

## 4. Déployer la configuration

Copier `dnsmasq.conf.example` vers la VM :

```bash
# Depuis votre poste (ou bastion future)
scp dns/dnsmasq.conf.example root@172.16.10.11:/etc/dnsmasq.conf
```

Ou coller manuellement le contenu de [dnsmasq.conf.example](dnsmasq.conf.example).

**Adapter** la ligne `interface=` au nom réel de l'interface (`ens18`, pas `eth0`).

```bash
sudo sed -i 's/^interface=.*/interface=ens18/' /etc/dnsmasq.conf
sudo dnsmasq --test
sudo systemctl enable --now dnsmasq
sudo systemctl status dnsmasq
```

## 5. Vérifications

Sur la VM DNS :

```bash
dig @127.0.0.1 dns.lab.local +short
dig @127.0.0.1 api.ocp.lab.local +short
dig @127.0.0.1 test.apps.ocp.lab.local +short
```

Résultats attendus :

```text
172.16.10.11
172.16.10.100
172.16.10.100
```

Depuis **Proxmox** (hôte `172.16.10.1`) :

```bash
dig @172.16.10.11 registry.lab.local +short
# → 172.16.10.20
```

## 6. Firewall (optionnel sur la VM)

```bash
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload
```

Ou, en lab minimal sans firewalld actif, laisser ouvert sur `vmbr1` isolé.

## Enregistrements DNS

| FQDN | IP |
|------|-----|
| `dns.lab.local` | `172.16.10.11` |
| `bastion.lab.local` | `172.16.10.10` |
| `registry.lab.local` | `172.16.10.20` |
| `api.ocp422.lab.local` | `172.16.10.100` |
| `*.apps.ocp422.lab.local` | `172.16.10.100` |
| `api.ocp5.lab.local` | `172.16.10.110` |
| `*.apps.ocp5.lab.local` | `172.16.10.110` |

## Dépannage

| Symptôme | Cause probable | Action |
|----------|----------------|--------|
| `dig` timeout depuis Proxmox | VM éteinte / mauvaise IP / firewall | `ping 172.16.10.11` |
| `dnsmasq` ne démarre pas | Port 53 pris par resolved | Désactiver `systemd-resolved` |
| Mauvaise réponse DNS | `interface=` incorrect | Aligner sur `nmcli device` |
| `eth0` vs `ens18` | Nom interface RHEL 10 | Mettre à jour `dnsmasq.conf` |

## Suite

- [ ] VM DNS opérationnelle
- [ ] Enregistrements résolus depuis Proxmox
- → Prochaine étape : [registry](../registry/README.md)

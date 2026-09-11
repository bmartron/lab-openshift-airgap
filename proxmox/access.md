# Accès aux VMs du lab

Les VMs sur `vmbr1` (`172.16.10.0/24`) ne sont **pas** joignables directement depuis le Mac (réseau isolé).

## Schéma

```
Mac (192.168.x.x)
  └── SSH ──► Proxmox (LAN + 172.16.10.1 sur vmbr1)
                └── SSH ──► VM lab (ex. 172.16.10.11)
```

## SSH via Proxmox (méthode actuelle)

```bash
# 1. Connexion à Proxmox
ssh root@<IP-proxmox-LAN>

# 2. Connexion à la VM du lab
ssh <user>@172.16.10.11
```

## Jump host depuis le Mac (optionnel)

Fichier `~/.ssh/config` :

```text
Host proxmox
  HostName 192.168.1.50
  User root

Host dns-lab
  HostName 172.16.10.11
  User bernard
  ProxyJump proxmox
```

```bash
ssh dns-lab
```

## Copier des fichiers (scp)

```bash
# Via Proxmox en 2 étapes
scp dns/dnsmasq.conf.example root@<IP-proxmox>:/tmp/
ssh root@<IP-proxmox> "scp /tmp/dnsmasq.conf.example bernard@172.16.10.11:/tmp/"
```

Ou avec ProxyJump (une commande) :

```bash
scp -o ProxyJump=root@<IP-proxmox> \
  dns/dnsmasq.conf.example bernard@172.16.10.11:/tmp/
```

## Console noVNC vs terminal

| Outil | Usage |
|-------|--------|
| **Terminal Mac / Cursor** | Travail quotidien, SSH, copier-coller |
| **Shell UI Proxmox** | Commandes rapides sur l'hôte (`ping`, `qm`) |
| **noVNC** | Install OS initiale, dépannage sans SSH |

Le copier-coller noVNC est limité sur Mac — préférer SSH dès que possible.

## Arrêt des VMs

| Action Proxmox | Type |
|----------------|------|
| **Shutdown** | Arrêt propre (ACPI) — **à utiliser** |
| **Stop** | Arrêt forcé — urgence seulement |

Installer `qemu-guest-agent` sur les VMs pour une meilleure intégration :

```bash
sudo dnf install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

Puis Proxmox → VM → **Options** → QEMU Guest Agent = activé.

## Futur : bastion double NIC

La VM `bastion` aura `vmbr0` + `vmbr1` → SSH direct depuis le Mac vers la bastion, puis accès au reste du lab.

# Accès aux VMs du lab

Les VMs sur `vmbr1` (`172.16.10.0/24`) ne sont **pas** joignables directement depuis le Mac (réseau isolé).

## Paramètres du lab (référence)

| Paramètre | Valeur |
|-----------|--------|
| Proxmox (LAN) | `root@192.168.1.147` |
| Utilisateur VMs | `bernard` |
| Jump host | `ProxyJump=root@192.168.1.147` |
| Gateway lab | `172.16.10.1` (Proxmox sur vmbr1) |

Variables : [versions.env.example](../versions.env.example) → copier en `versions.env`.

## Schéma

```
Mac (192.168.1.x)
  └── SSH/scp ──► Proxmox (192.168.1.147 + 172.16.10.1)
                    └── SSH/scp ──► VMs lab (172.16.10.x)
```

## SSH en 2 sauts (manuel)

```bash
ssh root@192.168.1.147
ssh bernard@172.16.10.11    # dns
ssh bernard@172.16.10.20    # registry
```

## SSH en 1 commande (ProxyJump depuis le Mac)

```bash
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.11
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20
```

## ~/.ssh/config (recommandé)

```text
Host proxmox
  HostName 192.168.1.147
  User root

Host dns-lab
  HostName 172.16.10.11
  User bernard
  ProxyJump proxmox

Host registry-lab
  HostName 172.16.10.20
  User bernard
  ProxyJump proxmox
```

```bash
ssh dns-lab
ssh registry-lab
```

## Copier des fichiers (scp) — depuis le Mac

> **Important** : lancer ces commandes sur le **Mac** (pas depuis une VM lab).  
> Les chemins `/Users/bmartron/...` n'existent que sur le Mac.

### Config DNS (dnsmasq)

```bash
scp -o ProxyJump=root@192.168.1.147 \
  "/Users/bmartron/Documents/Cursor/Projet 1/dns/dnsmasq.conf.example" \
  bernard@172.16.10.11:/tmp/dnsmasq.conf
```

### Image registry:2 (tar)

Préparer sur le Mac (Podman Desktop + Podman Machine) :

```bash
# Mac Apple Silicon → forcer amd64 pour les VMs x86_64 Proxmox
podman pull --platform linux/amd64 docker.io/library/registry:2
podman save -o ~/Downloads/registry2-amd64.tar docker.io/library/registry:2
```

Transférer vers la VM registry :

```bash
scp -o ProxyJump=root@192.168.1.147 \
  "/Users/bmartron/Downloads/registry2-amd64.tar" \
  bernard@172.16.10.20:/tmp/registry2-amd64.tar
```

Sur la VM registry :

```bash
sudo podman load -i /tmp/registry2-amd64.tar
sudo podman images | grep registry
```

### Variante en 2 étapes (si ProxyJump pose problème)

```bash
# Mac → Proxmox
scp "/Users/bmartron/Downloads/registry2.tar" root@192.168.1.147:/tmp/

# Proxmox → VM registry
ssh root@192.168.1.147
scp /tmp/registry2.tar bernard@172.16.10.20:/tmp/
```

## Résolution DNS sur Proxmox (hosts uniquement)

Les VMs lab utilisent **dnsmasq** (`172.16.10.11`). Proxmox doit **garder le DNS maison** pour les mises à jour (`apt`, subscriptions).

| Méthode | Recommandation |
|---------|----------------|
| DNS maison dans `/etc/resolv.conf` | **Conserver** — updates Proxmox |
| Remplacer par `172.16.10.11` | **Non** — casse la résolution Internet |
| `/etc/hosts` pour les noms lab | **Oui** — confort admin |

Ajouter sur **Proxmox** (voir [hosts.lab.example](hosts.lab.example)) :

```bash
sudo tee -a /etc/hosts << 'EOF'

# Lab OpenShift air-gap
172.16.10.11  dns.lab.local dns
172.16.10.20  registry.lab.local registry
172.16.10.10  bastion.lab.local bastion
172.16.10.100 api.ocp422.lab.local
172.16.10.110 api.ocp5.lab.local
EOF
```

Vérifier :

```bash
curl -k https://registry.lab.local:5000/v2/_catalog
```

Alternative : utiliser les **IP directes** (`172.16.10.20`) — pas besoin de `/etc/hosts`.

## Console noVNC vs terminal

| Outil | Usage |
|-------|--------|
| **Terminal Mac / Cursor** | SSH, scp, copier-coller — **quotidien** |
| **Shell UI Proxmox** | `ping`, `dig`, `qm` — commandes rapides |
| **noVNC** | Install OS initiale uniquement |

## Arrêt des VMs

| Action Proxmox | Type |
|----------------|------|
| **Shutdown** | Arrêt propre (ACPI) — **à utiliser** |
| **Stop** | Arrêt forcé — urgence seulement |

## Futur : bastion double NIC

La VM `bastion` (`172.16.10.10`) aura `vmbr0` + `vmbr1` → SSH direct depuis le Mac vers la bastion.

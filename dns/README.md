# VM DNS — `dns.lab.local`

Serveur DNS interne du lab air-gap. Résolution locale uniquement (pas d'upstream Internet).

> **Ansible** : procédures manuelles ci-dessous + bloc *Équivalent Ansible* ; table globale → [docs/ansible-manual-parity.md](../docs/ansible-manual-parity.md).

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
| Netmask | `255.255.255.0` (`/24`) |
| Gateway | `172.16.10.1` (Proxmox) |
| Hostname | `dns.lab.local` |

## 1. Créer la VM dans Proxmox

1. **Create VM** → VM ID libre (ex. `110`)
2. **OS** : ISO RHEL 10 (depuis datastore NFS)
3. **Disks** : 10 Go, storage NFS, cache `none`
4. **CPU** : 1 core — **Memory** : 1024 Mo
5. **Network** : Bridge **`vmbr1`**, VirtIO
6. Installation **minimale** — configurer l'utilisateur admin (ex. `bernard`)

> Accès SSH : les VMs sur `vmbr1` ne sont pas joignables depuis le Mac. Passer par **Proxmox** — voir [proxmox/access.md](../proxmox/access.md).

## 2. Réseau statique (minimum de commandes)

```bash
nmcli con mod ens18 ipv4.addresses 172.16.10.11/24 ipv4.gateway 172.16.10.1 ipv4.dns 127.0.0.1 ipv4.method manual ipv6.method disabled
nmcli con up ens18
hostnamectl set-hostname dns.lab.local
```

Adapter `ens18` si besoin (`nmcli device status`).

Vérifier depuis **Proxmox** :

```bash
ping -c 2 172.16.10.11
```

## 3. Repo DVD RHEL (sans souscription)

Sur `vmbr1` isolé, pas d'Internet → utiliser le **DVD RHEL 10 complet** comme repo local.

Voir [rhel/dvd-repo.md](../rhel/dvd-repo.md) pour la procédure complète.

Résumé :

```bash
sudo mount /dev/sr1 /mnt/rhel   # cloud-init = sr0 ; DVD ide2 = souvent sr1 — lsblk -f
sudo cp rhel-dvd.repo /etc/yum.repos.d/rhel-dvd.repo   # depuis le repo git ou copier le .example
# Désactiver plugin subscription-manager (voir rhel/dvd-repo.md)
sudo dnf install -y dnsmasq bind-utils
```

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Prérequis** | ISO RHEL complète (`ide2` / souvent `/dev/sr1`) ; inventaire + clé SSH — [ansible/README.md](../ansible/README.md) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | Rôle `rhel_dvd` (montage DVD, repo local, désactivation repos CDN) + paquets `dnsmasq` / `bind-utils` via `common`/`dns` |
| **Hors Ansible** | Réseau statique §2 ; contenu `/etc/dnsmasq.conf` §4 |

## 4. Configurer dnsmasq

```bash
sudo dnf install -y dnsmasq bind-utils
sudo systemctl disable --now systemd-resolved 2>/dev/null; true
```

> **RHEL 10** : sans `listen-address=172.16.10.11`, dnsmasq écoute uniquement sur `127.0.0.1`  
> (log : `DNS service limited to localhost`). Les autres VMs ne pourront pas joindre le DNS.

Déployer [dnsmasq.conf.example](dnsmasq.conf.example) → `/etc/dnsmasq.conf`.

**Depuis le Mac** (pas depuis la VM) :

```bash
scp -o ProxyJump=root@192.168.1.147 \
  "/Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/dns/dnsmasq.conf.example" \
  bernard@172.16.10.11:/tmp/dnsmasq.conf
```

Sur la VM DNS :

```bash
sudo cp /tmp/dnsmasq.conf /etc/dnsmasq.conf
sudo sed -i 's/^interface=.*/interface=ens18/' /etc/dnsmasq.conf
sudo dnsmasq --test
sudo systemctl enable --now dnsmasq
```

Ou créer le fichier directement sur la VM avec `sudo tee` — voir le contenu dans [dnsmasq.conf.example](dnsmasq.conf.example).

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | Paquets, chrony serveur NTP, firewall DNS/NTP, drop-in systemd dnsmasq (§ *dnsmasq au reboot*) |
| **Hors Ansible** | Déployer [dnsmasq.conf.example](dnsmasq.conf.example) → `/etc/dnsmasq.conf` (`scp` + `sed interface=` ci-dessus) |

## 5. Vérifications

Sur la VM DNS :

```bash
dig @127.0.0.1 api.ocp422.lab.local +short    # → 172.16.10.100
dig @127.0.0.1 api.ocp5.lab.local +short      # → 172.16.10.110
dig @127.0.0.1 test.apps.ocp422.lab.local +short
```

Depuis **Proxmox** et **bastion** :

```bash
dig @172.16.10.11 registry.lab.local +short   # → 172.16.10.20
```

## 6. NTP (serveur lab) + fuseau horaire

Le cluster agent exige une horloge synchronisée. La VM DNS fait office de **serveur NTP** pour le lab air-gap.

```bash
sudo dnf install -y chrony
sudo tee /etc/chrony.d/lab.conf << 'EOF'
allow 172.16.10.0/24
cmdallow 172.16.10.0/24
local stratum 10
rtcsync
makestep 1.0 3
EOF

# Pas d'Internet sur dns — désactiver les pools externes
sudo sed -i 's/^pool /#pool /' /etc/chrony.conf
sudo sed -i 's/^server /#server /' /etc/chrony.conf
sudo systemctl enable --now chronyd
sudo systemctl restart chronyd

sudo firewall-cmd --permanent --add-service=ntp
sudo firewall-cmd --reload

chronyc tracking
```

Fuseau horaire **Europe/Paris** (toutes les VMs lab) :

```bash
sudo timedatectl set-timezone Europe/Paris
timedatectl
```

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | Rôle `dns` : chrony serveur (`/etc/chrony.d/lab.conf`), pools externes commentés, firewall `dns` + `ntp` ; rôle `common` : fuseau `Europe/Paris` si défini dans `group_vars` |
| **Hors Ansible** | `additionalNTPSources` dans `agent-config.yaml` (install OCP) |

Dans `agent-config.yaml` du cluster :

```yaml
additionalNTPSources:
- 172.16.10.11
```

> Ne pas mettre `additionalNtpServers` dans `install-config.yaml` (champ invalide).

## 7. Firewall (obligatoire sur RHEL)

Sans cette règle, les autres VMs reçoivent `host unreachable` sur le port 53 (le ping fonctionne quand même).

```bash
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload
```

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | Rôle `dns` : `firewall-cmd --add-service=dns` et `ntp` |

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

## dnsmasq au reboot (recommandé)

Le rôle Ansible `dns` déploie `/etc/systemd/system/dnsmasq.service.d/after-network.conf` (`After=network-online.target`, `Restart=on-failure`) — voir `ansible/playbooks/lab-infra.yml`.

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | Drop-in `after-network.conf` + `systemctl enable` dnsmasq |

Manuel (si pas encore passé par Ansible), sur la VM **DNS** `172.16.10.11` :

```bash
sudo systemctl edit dnsmasq
```

Contenu :

```ini
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=on-failure
RestartSec=5
```

Puis `sudo systemctl daemon-reload` et `sudo systemctl restart dnsmasq`.

## Dépannage

| Symptôme | Cause probable | Action |
|----------|----------------|--------|
| `dnf`: no enabled repositories | Pas de souscription / pas de repo DVD | [rhel/dvd-repo.md](../rhel/dvd-repo.md) |
| SSH depuis Mac timeout | Réseau isolé | SSH via Proxmox — [proxmox/access.md](../proxmox/access.md) |
| `dig` timeout / `host unreachable` depuis bastion | Firewall DNS fermé | `firewall-cmd --add-service=dns` |
| `DNS service limited to localhost` | `listen-address` manquant | Ajouter `listen-address=172.16.10.11` |
| `dig` timeout | VM down | `ping 172.16.10.11` |
| `dnsmasq` failed au boot (`listening socket`) | Réseau pas prêt | `systemctl start dnsmasq` ; voir drop-in ci-dessous |
| `dnsmasq` ne démarre pas | Port 53 pris | Désactiver `systemd-resolved` |
| Mauvaise réponse DNS | `interface=` incorrect | Aligner sur `nmcli device` |

## Progression

- [x] Bridge `vmbr1` sur Proxmox
- [x] VM DNS créée (RHEL 10)
- [x] Réseau statique `172.16.10.11`
- [x] Repo DVD local (sans souscription)
- [x] dnsmasq (`listen-address` + firewall DNS)
- [x] `dig` OK depuis bastion et Proxmox
- [x] chrony NTP serveur lab (`172.16.10.11`)
- [x] Fuseau horaire Europe/Paris

→ Suite : [openshift/4.22-ga](../openshift/4.22-ga/README.md)

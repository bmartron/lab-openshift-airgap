# Repo local RHEL 10 via DVD (sans souscription)

Procédure pour installer des paquets sur les VMs **infra** du lab (`vmbr1` isolé) **sans Internet** et **sans `subscription-manager`**, en utilisant le DVD/ISO RHEL 10 complet (BaseOS + AppStream).

Applicable à : `dns`, `registry`, `bastion` (phase install).

## Prérequis

- ISO/DVD RHEL 10 **complet** (pas l'ISO boot minimal seul)
- Après montage : présence des répertoires `BaseOS/` et `AppStream/`

## 1. Attacher l'ISO dans Proxmox

VM → **Hardware** → **CD/DVD Drive** → sélectionner l'ISO RHEL 10 sur le NFS.

## 2. Monter le DVD sur la VM

```bash
sudo mkdir -p /mnt/rhel
sudo mount /dev/sr0 /mnt/rhel
ls /mnt/rhel
# Attendu : BaseOS  AppStream
```

Montage permanent (tant que l'ISO reste attachée) :

```bash
echo '/dev/sr0 /mnt/rhel iso9660 ro,defaults 0 0' | sudo tee -a /etc/fstab
```

## 3. Déclarer les repos locaux

> Le fichier `rhel-dvd.repo` **n'existe pas** sur la VM par défaut.  
> Utiliser `tee` directement sur la VM, ou `scp` depuis le Mac — voir [proxmox/access.md](../proxmox/access.md).

**Méthode recommandée** — créer sur la VM :

```bash
sudo tee /etc/yum.repos.d/rhel-dvd.repo << 'EOF'
[rhel10-baseos]
name=RHEL 10 BaseOS (DVD)
baseurl=file:///mnt/rhel/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[rhel10-appstream]
name=RHEL 10 AppStream (DVD)
baseurl=file:///mnt/rhel/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
```

**Alternative** — copier depuis le Mac :

```bash
scp -o ProxyJump=root@192.168.1.147 \
  "/Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/rhel/rhel-dvd.repo.example" \
  bernard@172.16.10.20:/tmp/rhel-dvd.repo

# Sur la VM
sudo cp /tmp/rhel-dvd.repo /etc/yum.repos.d/rhel-dvd.repo
```

Référence : [rhel-dvd.repo.example](rhel-dvd.repo.example)

## 4. Désactiver subscription-manager pour DNF

Sans cette étape, `dnf` cherche des repos RHSM inexistants.

```bash
sudo tee /etc/dnf/plugins/subscription-manager.conf << 'EOF'
[main]
enabled=0
EOF

sudo subscription-manager config --rhsm.manage_repos=0 2>/dev/null || true
```

## 5. Installer des paquets

```bash
sudo dnf clean all
sudo dnf repolist
sudo dnf install -y dnsmasq bind-utils    # exemple DNS
```

## Dépannage

| Symptôme | Cause | Action |
|----------|-------|--------|
| `Unable to read consumer identity` | Normal sans souscription | Utiliser repo DVD + désactiver plugin RHSM |
| Pas de `AppStream` sur le DVD | ISO boot seulement | Utiliser le DVD complet |
| `No package dnsmasq` | Mauvais chemin | `find /mnt/rhel -name 'dnsmasq*'` |
| Message login `rhc connect` | Cosmétique | Ignorable en lab |

## Alternative : repo NFS permanent

Pour ne pas garder le DVD sur chaque VM :

1. Copier `BaseOS/` + `AppStream/` sur le NAS (une fois)
2. Monter en NFS sur les VMs infra
3. Adapter `baseurl=` dans `rhel-dvd.repo`

Utile pour `registry` (gros volume de paquets : `podman`, etc.).

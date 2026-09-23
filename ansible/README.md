# Ansible — configuration lab infra

Configure **DNS**, **registry** (disque données + Podman), **bastion** (NTP client, script preflight).  
À lancer **depuis le Mac** (ProxyJump Proxmox) ou depuis la bastion pour les hôtes lab uniquement.

> Chaque procédure manuelle des guides **dns**, **registry**, **bastion**, **rhel/dvd-repo**, **lab-power-cycle** indique le playbook équivalent (bloc *Équivalent Ansible*). Vue d’ensemble : [docs/ansible-manual-parity.md](../docs/ansible-manual-parity.md).

## Prérequis

```bash
brew install ansible          # Mac (recommandé)
# ou : dnf install ansible-core  (sur bastion / RHEL)
```

## Inventaire

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
# (équivalent : cp group_vars/all.yml.example group_vars/all.yml)
# Obligatoire : registry_data_device, registry_image_tar (chemin .tar sur le Mac)
# Éditer hosts.yml : IP LAN bastion, user SSH ; all.yml : disque + chemin .tar
```

Connexion typique depuis le **Mac** :

- `bastion` : SSH direct sur IP LAN (`vmbr0`)
- `dns`, `registry` : `ansible_host` = IP lab + `ProxyJump` via Proxmox (voir `hosts.yml.example`)

## Registry seule (ton cas actuel)

Après install RHEL + SSH sur **172.16.10.20** :

1. Sur le **Mac**, image amd64 (une fois) :

```bash
podman pull --platform linux/amd64 docker.io/library/registry:2
podman save -o ~/Downloads/registry2-amd64.tar docker.io/library/registry:2
```

2. `group_vars/all.yml` :

- `registry_data_device` : clone template → `/dev/vdb` ; install ISO → `/dev/sdb` ou `/dev/sdb1` (`lsblk`)
- `registry_image_tar` : chemin absolu du `.tar` sur le Mac
- `registry_tls_mode: generate`

3. Lancer :

```bash
cd ansible
ansible-playbook playbooks/registry.yml --ask-become-pass   # -K : mot de passe sudo de bernard
```

Sur une install RHEL standard, `bernard` est dans **wheel** mais sudo **demande un mot de passe** — sans `-K` : `Missing sudo password`.

Option lab (sur la VM, une fois) : sudo sans mot de passe pour l’automation — `sudo visudo` → `bernard ALL=(ALL) NOPASSWD: ALL` (à n’utiliser que sur ce lab isolé).

Le playbook : repo **DVD RHEL** (ISO Proxmox sur `sr0`) → NTP → disque `/opt/registry` → `podman`/`openssl` → certs → `podman load` → conteneur `oc-registry`.

Sans ISO attachée : `No package podman available` — voir [rhel/dvd-repo.md](../rhel/dvd-repo.md).

4. Copier la CA sur le bastion pour `oc-mirror` — [registry/README.md](../registry/README.md) §5.

Disque seulement (sans Podman) :

```bash
ansible-playbook playbooks/registry-data-disk.yml
```

## Playbooks

| Playbook | Rôle |
|----------|------|
| `playbooks/registry.yml` | **Registry** : disque, TLS, image, conteneur |
| `playbooks/lab-infra.yml` | DNS → registry → bastion (ordre boot lab) |
| `playbooks/registry-data-disk.yml` | Seulement disque `/opt/registry` |
| `playbooks/bastion-ocp-install.yml` | **Bastion** : `install-config`, `agent-config`, `imageset`, CA, pull-secret (sans YAML manuel) |
| `playbooks/bastion-scripts.yml` | **Bastion** : copie `~/lab/scripts/*.sh` seulement (**pas** de sudo / dnf) |

### Install OCP sur la bastion (Ansible)

Guide détaillé : **[docs/ansible-ocp-install.md](../docs/ansible-ocp-install.md)** (quand relancer, fichiers déployés, ISO, dépannage).

Résumé :

1. **Mac** — [files/README.md](files/README.md) : `files/pull-secret.txt`, `files/install_ssh_key.pub` (gitignorés).
2. **`ocp_sno_mac`** dans `group_vars/all.yml` (racine `ansible/`, chargé en priorité par le playbook) ou `inventory/group_vars/all.yml`.
3. Inventaire : `bastion` + `registry` (jump Proxmox dans `hosts.yml`).

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

**Effet** : templates Jinja → `~/lab/4.22-ga/config-backup/` + copies dans `~/lab/4.22-ga/`, `~/lab/ca.crt`, trust registry pour `oc`, scripts `~/lab/scripts/`.

| Variable | Rôle |
|----------|------|
| `ocp_imageset_profile` | `platform-only` \| `gitops` \| `virtualization` \| `lvms` \| `odf` \| `rook-ceph` \| `virt-lvms` |
| `ocp_agent_generate_iso` | `true` = `openshift-install agent create image` sur la bastion |
| `ocp_push_iso_to_proxmox` | `true` = `scp` ISO bastion → `root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/` |
| `ocp_virt_operator_version` | ex. `4.22.9` (canal stable Virt) |

Défauts : [roles/ocp_bastion_install/defaults/main.yml](roles/ocp_bastion_install/defaults/main.yml).

```bash
ansible-playbook playbooks/lab-infra.yml --limit registry
```

### DNF / `rhel10-baseos` (DNS ou registry, air-gap)

Symptôme : échec sur le rôle **common**, tâche **Paquets de base** — `Failed to download metadata for repo 'rhel10-baseos'`.

Cause : la VM sur `vmbr1` n’a pas Internet ; **common** lance `dnf` avant que le repo **DVD** (`file:///mnt/rhel/...`) soit monté et activé.

Actions :

1. Proxmox : ISO RHEL 10 **complète** attachée sur la VM (CD/DVD `ide2`, ex. `sr0`) — [rhel/dvd-repo.md](../rhel/dvd-repo.md).
2. Relancer le playbook (le rôle `rhel_dvd` est exécuté **avant** `common` pour `dns` et `registry` dans `lab-infra.yml` et `registry.yml`).

```bash
cd ansible
ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass
```

La bastion (play séparé dans `lab-infra.yml`) n’inclut pas `rhel_dvd` en tête de play : si elle est aussi sans repo, attacher l’ISO ou mettre `rhel_dvd_repo_enable: false` et configurer les repos manuellement.

Check sans modifier :

```bash
ansible-playbook playbooks/registry.yml --check --diff
```

(`--check` peut échouer sur `podman` / `mkfs` — normal.)

### SSH / ProxyJump (erreur « port 65535 »)

1. Tester comme Ansible :

```bash
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20
```

2. Inventaire : `ansible_ssh_common_args` **en dur** (voir `hosts.yml.example`), pas `{{ proxmox_jump }}`.
3. `ansible.cfg` : `ControlMaster=no` (déjà configuré).
4. Ping Ansible :

```bash
ansible registry -m ping
```

Si **`root@192.168.1.147: Permission denied`** : Ansible **ne demande pas** le mot de passe du jump Proxmox (contrairement à ton `ssh` interactif).

**Correctif recommandé (Mac, une fois)** :

```bash
ssh-copy-id root@192.168.1.147
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20   # plus de password Proxmox
ansible registry -m ping
```

Si **`bernard@172.16.10.11` (ou `.20`) : Permission denied (publickey)`** : le jump Proxmox est OK, mais la clé SSH du **Mac** n’est pas dans `~bernard/.ssh/authorized_keys` sur la VM (la bastion en LAN a souvent déjà la clé ; DNS/registry sur `vmbr1` non).

```bash
ssh-copy-id -o ProxyJump=root@192.168.1.147 bernard@172.16.10.11
ansible dns -m ping
```

(Même commande avec `172.16.10.20` pour le registry.)

**Autres options** : jump **bastion** (`hosts.yml.example` méthode B), `hosts.sshconfig.yml.example`, ou playbook depuis la bastion (`hosts.from-bastion.yml.example`).

Voir [proxmox/access.md](../proxmox/access.md).

## Variables registry (résumé)

| Variable | Description |
|----------|-------------|
| `registry_data_device` | Clone : `/dev/vdb` ; ISO : `/dev/sdb` — vide = pas de formatage |
| `registry_tls_mode` | `generate` \| `copy` \| `skip` |
| `registry_image_tar` | Tar `podman save` sur le Mac |
| `registry_recreate_container` | `true` pour `podman rm` + recréer |

## Relation Terraform

1. `terraform apply` (nouvelles VMs)  
2. `ansible-playbook playbooks/registry.yml`  
3. Mirror / install OCP — docs existantes

Pour le lab **déjà en place** : sauter Terraform, ajuster `inventory/hosts.yml` et lancer Ansible.

## Secrets

- `inventory/hosts.yml`, `group_vars/all.yml` : **gitignorés**
- `files/registry-certs/` : gitignoré (mode `copy`)

# Mise à jour des configs install OCP via Ansible

Automatise le déploiement sur la **bastion** (`192.168.1.144`) : plus d’édition manuelle de `install-config.yaml` (CA, `pullSecret`, `imageContentSources`).

**Périmètre** : YAML install + pull-secret + imageset (+ re-trust CA).  
**Hors scope** (déjà `lab-infra.yml`) : DVD, gateway/DNS eth0, paquets, clients `oc`/`oc-mirror`, `/etc/hosts`.

## Quand lancer le playbook

| Situation | Action |
|-----------|--------|
| Après `lab-infra` + avant / après mirror | `bastion-ocp-install.yml` |
| Nouvelle install SNO / régénération ISO | puis `openshift-install agent create image` |
| Registry réinstallée (nouvelle CA) | Re-lancer (CA lue depuis `172.16.10.20`) + regénérer l’ISO |
| Changement MAC SNO, IP, imageset | Modifier `inventory/group_vars/all.yml` + re-lancer |
| Bastion **recréée** (Terraform) | Resync `install_ssh_key.pub` depuis la nouvelle bastion |

## Prérequis (Mac)

```bash
brew install ansible
cd ansible
# lab-infra déjà OK sur dns / registry / bastion
cp inventory/hosts.yml.example inventory/hosts.yml   # une fois
# Éditer inventory/group_vars/all.yml (source de vérité — pas ansible/group_vars/)
```

### Secrets locaux (non versionnés)

Voir [ansible/files/README.md](../ansible/files/README.md) :

```bash
cp ~/Downloads/pull-secret.txt ansible/files/pull-secret.txt
# Clé publique **bastion** (convention lab — pas la clé Mac) :
scp bernard@192.168.1.144:~/.ssh/id_ed25519.pub ansible/files/install_ssh_key.pub
```

### Variables obligatoires

Dans **`ansible/inventory/group_vars/all.yml`** :

| Variable | Exemple | Description |
|----------|---------|-------------|
| `ocp_sno_mac` | `BC:24:11:E1:8F:82` | MAC Proxmox VM SNO (`qm config <VMID> \| grep net`) |
| `ocp_imageset_profile` | `virt-lvms` | `platform-only` \| `gitops` \| `virtualization` \| `lvms` \| `odf` \| `rook-ceph` \| `virt-lvms` |
| `ocp_agent_generate_iso` | `false` | `true` = lance `openshift-install` sur la bastion |

## Commande

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

Le play **registry** lit `/opt/registry/certs/ca.crt` ; le play **bastion** déploie les YAML, pull-secret et (re)applique le trust TLS.

## Fichiers créés sur la bastion

| Chemin bastion | Contenu |
|----------------|---------|
| `~/lab/4.22-ga/config-backup/install-config.yaml` | Plateforme 4.22.12, miroirs, CA, pullSecret, sshKey |
| `~/lab/4.22-ga/config-backup/agent-config.yaml` | IP `172.16.10.100`, MAC, DNS, NTP |
| `~/lab/4.22-ga/install-config.yaml` | Copie active (pour `openshift-install`) |
| `~/lab/4.22-ga/agent-config.yaml` | Idem |
| `~/lab/4.22-ga/imageset-config.yaml` | Profil choisi (ex. Virt 4.22.9) |
| `~/lab/ca.crt` | CA registry |
| `~/lab/pull-secret.txt` | Pull secret Red Hat |
| `~/lab/scripts/*.sh` | Preflight mirror, scripts secours |

## Mettre à jour install-config + pullSecret registry + ISO

Quand l’install affiche *Mirror registry not found in pullSecret* ou après changement de CA :

1. **Mac** — pull secret Red Hat à jour dans `ansible/files/pull-secret.txt` (le playbook **ajoute** `registry.lab.local:5000` si absent).
2. **Mac** :

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

3. **ISO** — une des deux options :
   - `ocp_agent_generate_iso: true` dans `inventory/group_vars/all.yml`, puis relancer le même playbook (long, sur la bastion) ;
   - **ou** manuellement sur la **bastion** (voir ci-dessous).

Les YAML d’install n’exigent pas de rejouer `lab-infra` (déjà fait pour OS / clients / réseau).

## ISO agent (après playbook)

Si `ocp_agent_generate_iso: false` (défaut), sur la **bastion** :

```bash
cd ~/lab/4.22-ga
rm -f .openshift_install_state.json agent.x86_64.iso
openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir .
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
```

### Copier l’ISO vers Proxmox (NFS)

**Ansible** (depuis le Mac, après génération ISO sur la bastion) — dans `inventory/group_vars/all.yml` :

```yaml
ocp_push_iso_to_proxmox: true
# optionnel : ocp_proxmox_host, ocp_proxmox_iso_dir (défauts = lab NUC)
```

Prérequis : **`bernard@bastion`** peut `scp` vers **`root@192.168.1.147`** (`ssh-copy-id root@192.168.1.147` depuis la bastion).

Relancer : `ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass`

**Manuel** sur la bastion :

```bash
scp ~/lab/4.22-ga/agent.x86_64.iso \
  root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/
```

Dans l’UI Proxmox : datastore **`nfs_iso`** → ISO **`agent.x86_64.iso`** → attacher en **ide2** sur la VM SNO. Voir [proxmox/sno-vm.md](../proxmox/sno-vm.md).

Puis attacher et booter — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).

## Dépannage

| Erreur Ansible | Cause |
|----------------|--------|
| `ocp_sno_mac` invalide | MAC vide ou mauvais fichier `group_vars` |
| CA absente | Play registry échoué ou `ca.crt` manquant sur `172.16.10.20` |
| pull-secret / ssh key | Fichiers manquants dans `ansible/files/` sur le Mac |
| `Host key changed` registry | `ssh-keygen -R 172.16.10.20` sur la bastion après reinstall VM |

Scripts manuels (secours) : [bastion/scripts/](../bastion/scripts/) (`install-config-regenerate.sh`, etc.).

Synchroniser les scripts vers la bastion **sans** rejouer `lab-infra` :

```bash
cd ansible
ansible-playbook playbooks/bastion-scripts.yml
```

## Voir aussi

- [ansible/README.md](../ansible/README.md) — inventaire, registry, SSH jump
- [mirror/README.md](../mirror/README.md) — `oc-mirror` après imageset déployé

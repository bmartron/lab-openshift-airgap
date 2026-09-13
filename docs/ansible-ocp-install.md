# Mise à jour des configs install OCP via Ansible

Automatise le déploiement sur la **bastion** (`192.168.1.144`) : plus d’édition manuelle de `install-config.yaml` (CA, `pullSecret`, `imageContentSources`).

## Quand lancer le playbook

| Situation | Action |
|-----------|--------|
| Nouvelle install SNO / régénération ISO | `bastion-ocp-install.yml` puis `openshift-install agent create image` |
| Registry réinstallée (nouvelle CA) | Re-lancer le playbook (CA lue depuis `172.16.10.20`) + regénérer l’ISO |
| Changement MAC SNO, IP, imageset (Virt/GitOps) | Modifier `group_vars` + re-lancer le playbook |
| Après `oc-mirror` (chemins inchangés) | Optionnel — ITMS déjà dans le template `ocp4-422` |

## Prérequis (Mac)

```bash
brew install ansible
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp group_vars/all.yml.example group_vars/all.yml
# ou inventory/group_vars/all.yml — le playbook charge aussi group_vars/all.yml (prioritaire)
```

### Secrets locaux (non versionnés)

Voir [ansible/files/README.md](../ansible/files/README.md) :

```bash
cp ~/Downloads/pull-secret.txt ansible/files/pull-secret.txt
cp ~/.ssh/id_ed25519.pub ansible/files/install_ssh_key.pub
```

### Variables obligatoires

Dans **`ansible/group_vars/all.yml`** (recommandé) :

| Variable | Exemple | Description |
|----------|---------|-------------|
| `ocp_sno_mac` | `BC:24:11:E1:8F:82` | MAC Proxmox VM SNO (`qm config <VMID> \| grep net`) |
| `ocp_imageset_profile` | `virtualization` | `platform-only` \| `gitops` \| `virtualization` |
| `ocp_agent_generate_iso` | `false` | `true` = lance `openshift-install` sur la bastion |

MAC et versions Virt : [roles/ocp_bastion_install/defaults/main.yml](../ansible/roles/ocp_bastion_install/defaults/main.yml).

Inventaire : hôtes **`bastion`** + **`registry`** (jump Proxmox) — [inventory/hosts.yml.example](../ansible/inventory/hosts.yml.example).

## Commande

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

Le play **registry** lit `/opt/registry/certs/ca.crt` ; le play **bastion** déploie les fichiers et configure le trust TLS (`update-ca-trust`, `certs.d`).

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

## ISO agent (après playbook)

Si `ocp_agent_generate_iso: false` (défaut), sur la **bastion** :

```bash
cd ~/lab/4.22-ga
rm -f .openshift_install_state.json agent.x86_64.iso
openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir .
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
```

Puis attacher `agent.x86_64.iso` sur Proxmox — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md), [proxmox/sno-vm.md](../proxmox/sno-vm.md).

## Dépannage

| Erreur Ansible | Cause |
|----------------|--------|
| `ocp_sno_mac` invalide | MAC vide ou mauvais fichier `group_vars` |
| CA absente | Play registry échoué ou `ca.crt` manquant sur `172.16.10.20` |
| pull-secret / ssh key | Fichiers manquants dans `ansible/files/` sur le Mac |
| `Host key changed` registry | `ssh-keygen -R 172.16.10.20` sur la bastion après reinstall VM |

Scripts manuels (secours) : [bastion/scripts/](../bastion/scripts/) (`install-config-regenerate.sh`, etc.).

Synchroniser les scripts vers la bastion **sans** `lab-infra` (évite dnf sur bastion air-gap) :

```bash
cd ansible
ansible-playbook playbooks/bastion-scripts.yml
```

## Voir aussi

- [ansible/README.md](../ansible/README.md) — inventaire, registry, SSH jump
- [mirror/README.md](../mirror/README.md) — `oc-mirror` après imageset déployé

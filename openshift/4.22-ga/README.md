# OpenShift 4.22 GA — installation agent-based (air-gap)

| Paramètre | Valeur |
|-----------|--------|
| Version | **4.22.12** (z-stream GA — vérifier la dernière sur console.redhat.com) |
| Kubernetes | 1.35 |
| Cluster name | `ocp422` |
| Base domain | `lab.local` |
| FQDN API | `api.ocp422.lab.local` |
| SNO IP | `172.16.10.100` |
| Mirror registry | `registry.lab.local:5000/ocp4-422` |

> **Important** : `baseDomain` = `lab.local` + `metadata.name` = `ocp422` → API sur `api.ocp422.lab.local`.  
> Ne pas mettre `baseDomain: ocp422.lab.local` (double sous-domaine).

## DNS requis

```
api.ocp422.lab.local        → 172.16.10.100
api-int.ocp422.lab.local    → 172.16.10.100
*.apps.ocp422.lab.local     → 172.16.10.100
```

## VM SNO (Proxmox)

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| Disque install | 120 Go, bus **SCSI** → `/dev/sda` dans `rootDeviceHints` |
| NIC | `vmbr1`, VirtIO, MAC notée pour `agent-config.yaml` |
| Boot | ISO agent `agent.x86_64.iso` |

Avant chaque nouvelle tentative : **effacer le disque** — voir [proxmox/sno-vm.md](../../proxmox/sno-vm.md).

## Prérequis bastion

```bash
sudo dnf install -y nmstate xorriso genisoimage
nmstatectl --version
which xorriso
```

| Prérequis | Détail |
|-----------|--------|
| `nmstate` | Requis pour valider `networkConfig` dans `agent-config.yaml` |
| `xorriso` / `genisoimage` | Requis pour `openshift-install agent create image` |
| `oc-mirror` v2 | Plugin séparé — voir [mirror/README.md](../../mirror/README.md) |
| `agent-config.yaml` | **`apiVersion: v1beta1`** (pas `v1`) |
| NTP | `additionalNTPSources` dans **agent-config** (pas dans install-config) |
| CA registry | `additionalTrustBundle` dans install-config |

Chemins mirror oc-mirror v2 dans `install-config.yaml` — vérifier contre `workspace/working-dir/cluster-resources/itms-oc-mirror.yaml` :

```yaml
imageContentSources:
- source: quay.io/openshift-release-dev/ocp-release
  mirrors:
  - registry.lab.local:5000/ocp4-422/openshift/release-images
- source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
  mirrors:
  - registry.lab.local:5000/ocp4-422/openshift/release
```

## Disque d'installation (`rootDeviceHints`)

Identifier le disque sur le SNO (phase live ISO, SSH `core@172.16.10.100`) :

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,TRAN
```

| Bus Proxmox | Device Linux typique |
|-------------|---------------------|
| SCSI (`drive-scsi0`) | `/dev/sda` |
| VirtIO Block | `/dev/vda` |
| SATA | `/dev/sda` |

Mettre à jour `agent-config.yaml` :

```yaml
rootDeviceHints:
  deviceName: /dev/sda
```

> Chemins `/dev/disk/by-id/...` **non acceptés** — seulement `/dev/*` ou `/dev/disk/by-path/*`.

Symptôme si mauvais disque : `failed to set installation disk path </dev/not-found-by-hints>` dans `journalctl -u assisted-service`.

## Workflow Ansible (recommandé)

Depuis le **Mac** : configs générées sans éditer le YAML à la main — [ansible/README.md](../../ansible/README.md) § *Install OCP sur la bastion*.

Prérequis : `ansible/files/pull-secret.txt`, `ansible/files/install_ssh_key.pub`, `ocp_sno_mac` dans `group_vars/all.yml`.

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

Puis ISO sur la bastion (ou `ocp_agent_generate_iso: true`).

## Workflow manuel

```bash
mkdir -p ~/lab/4.22-ga/config-backup
cd ~/lab/4.22-ga

# 1. Créer / éditer install-config.yaml et agent-config.yaml (MAC, IP, /dev/sda)
# 2. Sauvegarder AVANT génération ISO — openshift-install supprime les configs après create image
cp install-config.yaml agent-config.yaml config-backup/

openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir . --log-level info

# 3. Restaurer les configs pour regénérer l'ISO ou relancer wait-for
cp config-backup/install-config.yaml config-backup/agent-config.yaml .

# Copier agent.x86_64.iso vers NFS / Proxmox, boot VM SNO
openshift-install agent wait-for install-complete --dir . --log-level debug
```

> **Comportement normal** : `openshift-install agent create image` intègre les secrets dans l'ISO puis **supprime** `install-config.yaml` et `agent-config.yaml` du répertoire. Conserver une copie dans `config-backup/` (non versionné).

### Régénération ISO (dépannage)

Si `create image` échoue avec *Reusing previously-fetched Agent Installer ISO* sans détail :

```bash
rm -f .openshift_install_state.json agent.x86_64.iso
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir . --log-level debug
```

### Surveillance install (SSH SNO)

```bash
sudo journalctl -u assisted-service -f
# quand l'install démarre :
sudo journalctl -u bootkube -f
```

## Fin d'install et `wait-for`

Durée observée en lab : **~30 min** (mirror déjà en place).

`openshift-install agent wait-for install-complete` peut **échouer en timeout** avec une erreur TLS (`kube-apiserver-lb-signer`) alors que le cluster est **opérationnel**. Vérifier :

```bash
curl -k https://api.ocp422.lab.local:6443/healthz   # → ok
```

Critère de succès : `oc login` + nœud **Ready** + tous les ClusterOperators **Available** (voir ci-dessous).

## Après install

### DNS bastion (OAuth / console)

Le DNS maison (`192.168.1.1`) ne résout pas `*.apps.ocp422.lab.local`. Ajouter sur la **bastion** :

```bash
sudo tee -a /etc/hosts << 'EOF'

172.16.10.100  oauth-openshift.apps.ocp422.lab.local
172.16.10.100  console-openshift-console.apps.ocp422.lab.local
EOF
```

### Connexion `oc`

Le fichier `auth/kubeconfig` peut être obsolète (certs bootstrap). Utiliser `oc login` :

```bash
cd ~/lab/4.22-ga

oc login https://api.ocp422.lab.local:6443 \
  -u kubeadmin \
  -p "$(cat auth/kubeadmin-password)" \
  --insecure-skip-tls-verify=true

oc get nodes
oc get clusteroperators

cp ~/.kube/config ~/lab/4.22-ga/auth/kubeconfig
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
```

### Miroirs cluster (air-gap)

```bash
oc apply -f workspace/working-dir/cluster-resources/idms-oc-mirror.yaml
oc apply -f workspace/working-dir/cluster-resources/itms-oc-mirror.yaml
```

### Console web

| | |
|---|---|
| URL (depuis bastion / VM sur `vmbr1`) | `https://console-openshift-console.apps.ocp422.lab.local` |
| User | `kubeadmin` |
| Password | `cat ~/lab/4.22-ga/auth/kubeadmin-password` |

Depuis le **Mac** (lab isolé) : tunnel SSH ou VM graphique sur `vmbr1` — voir [proxmox/access.md](../../proxmox/access.md).

SSH SNO : utilisateur **`core`**, clé = `sshKey` de `install-config.yaml` (souvent clé Mac, pas bastion).

Voir aussi [mirror/README.md](../../mirror/README.md) pour les opérateurs air-gap (Virt, ODF).

## Réinstall de contrôle

Sans refaire le mirror registry :

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .

rm -f .openshift_install_state.json agent.x86_64.iso
openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir .

# Proxmox : wipe disque ou remplacer scsi0 — proxmox/sno-vm.md
openshift-install agent wait-for install-complete --dir . --log-level debug
```

Valider avec `oc login` + `oc get nodes` même si `wait-for` timeout.

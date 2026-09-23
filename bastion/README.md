# VM Bastion — RHEL 10

Poste d'orchestration : `oc`, `openshift-install`, `oc-mirror`, génération ISO agent.

> **Ansible** : [docs/ansible-manual-parity.md](../docs/ansible-manual-parity.md) · install OCP → [docs/ansible-ocp-install.md](../docs/ansible-ocp-install.md).

**Avantage double NIC** : SSH direct depuis le Mac (`vmbr0`) + accès au lab (`vmbr1`).

## Spécifications VM (Proxmox)

| Paramètre | Valeur |
|-----------|--------|
| Nom | `bastion` |
| OS | RHEL 10 minimal |
| vCPU | 2 |
| RAM | 8 Go |
| Disque | 40 Go (NFS) |
| **NIC 0** | `vmbr0` — admin / Internet |
| **NIC 1** | `vmbr1` — lab air-gap |
| IP admin | **`192.168.1.144`** (`vmbr0`) — SSH/scp depuis le Mac |
| IP lab | `172.16.10.10/24` |
| Hostname | `bastion.lab.local` |

## 1. Créer la VM dans Proxmox

1. **Create VM** — RHEL 10 minimal
2. **Network Device 0** : `vmbr0`, VirtIO
3. **Add Network Device 1** : `vmbr1`, VirtIO
4. Disque 40 Go NFS, 2 vCPU, 8 Go RAM

## 2. Réseau

### Interface lab (`vmbr1` — souvent `ens19`)

> Les commandes `nmcli con mod` nécessitent **`sudo`**.

```bash
sudo nmcli con mod ens19 ipv4.addresses 172.16.10.10/24 ipv4.gateway 172.16.10.1 \
  ipv4.dns 172.16.10.11 ipv4.dns-search lab.local ipv4.method manual ipv6.method disabled
sudo nmcli con up ens19
sudo hostnamectl set-hostname bastion.lab.local
```

### Interface admin (`vmbr0` — souvent `ens18`)

Laisser en **DHCP** (réseau maison) pour Internet et mises à jour :

```bash
sudo nmcli con mod ens18 ipv4.method auto
sudo nmcli con up ens18
```

Vérifier Internet :

```bash
ping -c 2 registry.redhat.io
curl -I https://mirror.openshift.com
```

### Résolution DNS lab (double NIC)

Noms lab → `/etc/hosts` (Ansible). Internet → **gateway + DNS** maison sur **eth0** (`192.168.1.1`).

**Piège** : si la gateway par défaut est `172.16.10.1` (eth1), le registry lab répond mais Internet échoue (`Network is unreachable` / timeout). Terraform : `gw` sur `ipconfig0` seulement.

**Ansible** : `dns_admin.yml` (route + DNS + `curl` mirror.openshift.com) dans `lab-infra.yml --limit bastion`.

**Manuel** (secours) :

```bash
sudo nmcli con mod "cloud-init eth0" ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.1 \
  ipv4.ignore-auto-dns yes ipv4.route-metric 100
sudo nmcli con mod "cloud-init eth1" ipv4.gateway "" ipv4.never-default yes \
  ipv4.ignore-auto-dns yes ipv4.dns "" ipv4.route-metric 200
sudo nmcli con up "cloud-init eth0" && sudo nmcli con up "cloud-init eth1"
ip -4 route show default   # attendu : via 192.168.1.1 dev eth0
curl -I https://mirror.openshift.com
```

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `bastion` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion` |
| **Couverture** | DNS admin, `/etc/hosts`, trust CA, paquets, clients OCP, test catalog |
| **Hors Ansible** | — |

| Symptôme | Cause | Action |
|----------|-------|--------|
| `Insufficient privileges` sur `nmcli` | Pas de `sudo` | Préfixer avec `sudo` |
| `Name or service not known` / `Network is unreachable` vers mirror.openshift.com | Default route = `172.16.10.1` (eth1) | Ansible `dns_admin` ou recreate TF avec gw sur eth0 |
| `curl registry.lab.local` échoue | Pas d’entrées `/etc/hosts` | Relancer rôle bastion |
| `oc login` : *no such host* `oauth-openshift.apps...` | Apps absents de `/etc/hosts` | Relancer rôle bastion |

## 3. Repo DVD + paquets (phase install)

La bastion a Internet via `vmbr0`, mais **sans souscription RH** le lab utilise le **DVD RHEL** (`ide2` / souvent `/dev/sr1`) — comme dns/registry.

Ansible : rôle `rhel_dvd` puis `bastion_packages` dans `lab-infra.yml`.

Manuel :

```bash
sudo mkdir -p /mnt/rhel && sudo mount /dev/sr1 /mnt/rhel
# repo : voir rhel/dvd-repo.md
sudo dnf install -y nmstate xorriso bind-utils
```

| Paquet | Usage |
|--------|-------|
| `nmstate` | `nmstatectl` — validation `agent-config.yaml` |
| `xorriso` | `openshift-install agent create image` |
| `bind-utils` | `dig` — [lab-startup-check.sh](scripts/lab-startup-check.sh) |

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `bastion` |
| **Prérequis** | ISO RHEL complète en `ide2` (`rhel_dvd_iso` Terraform) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion` |
| **Couverture** | `rhel_dvd` + paquets + clients OCP (`oc`, `openshift-install`, `oc-mirror`) |
| **Hors Ansible** | Souscription RH à la place du DVD si tu préfères |

## 4. Installer oc / openshift-install / oc-mirror (GA 4.22.12)

**Ansible (recommandé)** — Internet `vmbr0` requis :

```bash
cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion
```

Variable : `bastion_ocp_version` (défaut `4.22.12` / `ocp_platform_version`).

**Manuel** :

```bash
export OCP_VERSION=4.22.12
cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/openshift-client-linux-${OCP_VERSION}.tar.gz
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/openshift-install-linux-${OCP_VERSION}.tar.gz
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/oc-mirror.tar.gz
sudo tar xzf openshift-client-linux-${OCP_VERSION}.tar.gz -C /usr/local/bin oc kubectl
sudo tar xzf openshift-install-linux-${OCP_VERSION}.tar.gz -C /usr/local/bin openshift-install
tar xzf oc-mirror.tar.gz && sudo mv oc-mirror /usr/local/bin/ && sudo chmod +x /usr/local/bin/oc-mirror
oc version --client && openshift-install version && oc-mirror version --v2
```

## 5. Répertoires de travail

```bash
mkdir -p ~/lab/{4.22-ga,5-rc}
mkdir -p ~/.docker
```

Copier le **pull-secret** Red Hat → `~/lab/pull-secret.txt` (non versionné).

## 6. Trust registry lab (CA)

**Ansible (recommandé)** — déjà dans `lab-infra.yml` (rôle `bastion`) : `~/lab/ca.crt`, `certs.d` pour oc-mirror, trust store.

```bash
cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion
```

**Manuel** (secours) — récupérer la CA puis installer pour `oc-mirror` / `curl` / `oc` :

```bash
scp -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20:/opt/registry/certs/ca.crt ~/lab/ca.crt
# ou depuis la bastion : scp bernard@172.16.10.20:/opt/registry/certs/ca.crt ~/lab/ca.crt

sudo mkdir -p /etc/containers/certs.d/registry.lab.local:5000
sudo cp ~/lab/ca.crt /etc/containers/certs.d/registry.lab.local:5000/ca.crt
sudo cp ~/lab/ca.crt /etc/pki/ca-trust/source/anchors/registry-lab.crt
sudo update-ca-trust

curl --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog
```

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `lab-infra.yml` (trust CA) ; `bastion-ocp-install.yml` (configs install + re-trust) |
| **Hôte** | `bastion` (+ lecture CA sur `registry`) |
| **Commande (Mac)** | `ansible-playbook playbooks/lab-infra.yml --limit bastion` |
| **Couverture** | `~/lab/ca.crt`, `certs.d`, `update-ca-trust`, test catalog — [docs/ansible-manual-parity.md](../docs/ansible-manual-parity.md) |
| **Hors Ansible** | `scp` manuel ci-dessus si playbook non utilisé |

## 7. Piste RC 5 (optionnel, répertoire séparé)

```bash
mkdir -p ~/ocp-5-rc/bin && cd ~/ocp-5-rc/bin
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
tar xzf openshift-client-linux-*.tar.gz
tar xzf openshift-install-linux-*.tar.gz
export PATH=~/ocp-5-rc/bin:$PATH
```

## 8. oc-mirror v2 (GA 4.22.12)

Binaire installé avec la §4 (Ansible ou manuel). Procédure mirror : [mirror/README.md](../mirror/README.md).

## 9. Génération ISO agent

Voir [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) — workflow complet avec `config-backup/`.

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-ocp-install.yml` |
| **Variables** | `ocp_agent_generate_iso`, `ocp_push_iso_to_proxmox`, `ocp_imageset_profile` — [ansible/README.md](../ansible/README.md) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass` |

## Coupure quotidienne (arrêt / démarrage)

Ordre de boot : **DNS → registry → bastion → SNO**. Avant de démarrer le SNO sur Proxmox, lancer sur la bastion :

```bash
mkdir -p ~/lab/scripts   # une fois si absent
~/lab/scripts/lab-startup-check.sh   # copier depuis bastion/scripts/ du dépôt
```

Procédure complète, NTP, dépannage : [docs/lab-power-cycle.md](../docs/lab-power-cycle.md).

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-scripts.yml` (script seul) ou `lab-infra.yml --limit bastion` (NTP + script) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-scripts.yml --ask-become-pass` |
| **Couverture** | Copie `~/lab/scripts/lab-startup-check.sh` depuis le dépôt (pas de `dnf`) |

**NTP bastion** (client vers le DNS lab) :

```bash
sudo dnf install -y chrony
sudo tee /etc/chrony.d/lab.conf << 'EOF'
server 172.16.10.11 iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
EOF
sudo systemctl enable --now chronyd
timedatectl set-timezone Europe/Paris
```

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `bastion` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion --ask-become-pass` |
| **Couverture** | Rôles `common` + `bastion` : chrony client, fuseau, script preflight |

## Accès SSH depuis le Mac

Une fois la bastion créée, SSH **direct** (sans ProxyJump) :

```bash
ssh bernard@192.168.1.144
```

Puis depuis la bastion :

```bash
ssh bernard@172.16.10.20   # registry
dig @172.16.10.11 registry.lab.local
```

## Progression

- [x] VM créée (2 NICs)
- [x] Réseau lab `172.16.10.10` + admin Internet
- [x] DNS lab (`/etc/hosts` + DNS maison sur `ens18`)
- [x] `oc` + `openshift-install` + `oc-mirror` v2 — 4.22.12
- [x] CA registry (`~/lab/ca.crt` + trust système)
- [x] Pull secret (`~/lab/pull-secret.txt`)
- [x] `oc-mirror` v2 → `registry.lab.local:5000/ocp4-422` (~22 Go)
- [x] `nmstate`, `xorriso`, `bind-utils` installés
- [x] Install SNO GA 4.22.12 (validée + réinstall ~30 min)

→ Suite : opérateurs air-gap — [mirror](../mirror/README.md) ; VM SNO — [proxmox/sno-vm.md](../proxmox/sno-vm.md)

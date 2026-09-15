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

La bastion a besoin des **deux** résolveurs : DNS maison (Internet) + noms lab.

**Fix validé** — `/etc/hosts` pour le lab + DNS maison sur `ens18` :

```bash
sudo nmcli con mod ens18 ipv4.ignore-auto-dns no
sudo nmcli con up ens18
sudo nmcli con up ens19

sudo tee -a /etc/hosts << 'EOF'

172.16.10.11  dns.lab.local dns
172.16.10.20  registry.lab.local registry
172.16.10.10  bastion.lab.local bastion
172.16.10.100 api.ocp422.lab.local
172.16.10.100 oauth-openshift.apps.ocp422.lab.local
172.16.10.100 console-openshift-console.apps.ocp422.lab.local
EOF

dig mirror.openshift.com +short          # Internet OK
curl --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog
```

> `/etc/hosts` est consulté avant le DNS — les noms `*.lab.local` fonctionnent sans casser `mirror.openshift.com`.

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `bastion` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion --ask-become-pass` |
| **Couverture** | Client chrony vers DNS lab, script `lab-startup-check.sh` (si activé dans `group_vars`) |
| **Hors Ansible** | `/etc/hosts` et `nmcli` (§2) ; binaires OCP §4–§8 |

| Symptôme | Cause | Action |
|----------|-------|--------|
| `Insufficient privileges` sur `nmcli` | Pas de `sudo` | Préfixer avec `sudo` |
| `resolvectl` : *not activatable* | `systemd-resolved` inactif sur RHEL | Utiliser `/etc/hosts` + NetworkManager |
| `Could not resolve host: mirror.openshift.com` | DNS lab seul (sans Internet) | `ipv4.ignore-auto-dns no` sur `ens18` |
| `curl registry.lab.local` échoue | DNS maison ne connaît pas `lab.local` | Entrées `/etc/hosts` (ci-dessus) |
| `oc login` : *no such host* `oauth-openshift.apps...` | Apps non résolus par DNS maison | Lignes OAuth/console dans `/etc/hosts` |

## 3. Repo DVD + paquets (phase install)

Sur `vmbr1` seul, utiliser le DVD — [rhel/dvd-repo.md](../rhel/dvd-repo.md).

Avec Internet via `vmbr0`, enregistrement Red Hat ou DVD au choix.

```bash
sudo dnf install -y podman skopeo jq git bind-utils tar nmstate xorriso genisoimage
```

| Paquet | Usage |
|--------|-------|
| `nmstate` | Validation `agent-config.yaml` (`nmstatectl` requis par openshift-install) |
| `xorriso` / `genisoimage` | Génération ISO agent (`openshift-install agent create image`) |

## 4. Installer oc / openshift-install (GA 4.22.12)

```bash
export OCP_VERSION=4.22.12
cd /tmp

curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/openshift-client-linux-${OCP_VERSION}.tar.gz
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/openshift-install-linux-${OCP_VERSION}.tar.gz

sudo tar xzf openshift-client-linux-${OCP_VERSION}.tar.gz -C /usr/local/bin oc kubectl
sudo tar xzf openshift-install-linux-${OCP_VERSION}.tar.gz -C /usr/local/bin openshift-install

oc version
openshift-install version
```

## 5. Répertoires de travail

```bash
mkdir -p ~/lab/{4.22-ga,5-rc}
mkdir -p ~/.docker
```

Copier le **pull-secret** Red Hat → `~/lab/pull-secret.txt` (non versionné).

## 6. Trust registry lab (CA)

Récupérer la CA depuis la VM registry :

```bash
scp -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20:/opt/registry/certs/ca.crt ~/lab/ca.crt
```

Ou depuis la bastion (une fois sur vmbr1) :

```bash
scp bernard@172.16.10.20:/opt/registry/certs/ca.crt ~/lab/ca.crt
```

Installer la CA pour `oc-mirror`, `curl` et Podman :

```bash
sudo mkdir -p /etc/containers/certs.d/registry.lab.local:5000
sudo cp ~/lab/ca.crt /etc/containers/certs.d/registry.lab.local:5000/ca.crt

sudo cp ~/lab/ca.crt /etc/pki/ca-trust/source/anchors/registry-lab.crt
sudo update-ca-trust

curl --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog
```

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-ocp-install.yml` |
| **Hôte** | `bastion` (+ CA lue sur `registry`) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass` |
| **Couverture** | `~/lab/ca.crt`, trust registry pour `oc`, configs install — voir [docs/ansible-ocp-install.md](../docs/ansible-ocp-install.md) |
| **Hors Ansible** | `scp` manuel ci-dessus si pas de playbook |

## 7. Piste RC 5 (optionnel, répertoire séparé)

```bash
mkdir -p ~/ocp-5-rc/bin && cd ~/ocp-5-rc/bin
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
tar xzf openshift-client-linux-*.tar.gz
tar xzf openshift-install-linux-*.tar.gz
export PATH=~/ocp-5-rc/bin:$PATH
```

## 8. oc-mirror v2 (GA 4.22.12)

Installer le plugin (une fois) :

```bash
export OCP_VERSION=4.22.12
cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/oc-mirror.tar.gz
tar xzf oc-mirror.tar.gz
sudo mv oc-mirror /usr/local/bin/
sudo chmod +x /usr/local/bin/oc-mirror
oc-mirror --v2 --help
```

Procédure complète : [mirror/README.md](../mirror/README.md).

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
- [x] `nmstate`, `xorriso` installés
- [x] Install SNO GA 4.22.12 (validée + réinstall ~30 min)

→ Suite : opérateurs air-gap — [mirror](../mirror/README.md) ; VM SNO — [proxmox/sno-vm.md](../proxmox/sno-vm.md)

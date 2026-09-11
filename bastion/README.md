# VM Bastion — RHEL 10

Poste d'orchestration : `oc`, `openshift-install`, `oc mirror`, génération ISO agent.

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
| IP admin | DHCP ou statique LAN (ex. `192.168.1.x`) |
| IP lab | `172.16.10.10/24` |
| Hostname | `bastion.lab.local` |

## 1. Créer la VM dans Proxmox

1. **Create VM** — RHEL 10 minimal
2. **Network Device 0** : `vmbr0`, VirtIO
3. **Add Network Device 1** : `vmbr1`, VirtIO
4. Disque 40 Go NFS, 2 vCPU, 8 Go RAM

## 2. Réseau

### Interface lab (`vmbr1` — souvent `ens19`)

```bash
nmcli con mod ens19 ipv4.addresses 172.16.10.10/24 ipv4.gateway 172.16.10.1 \
  ipv4.dns 172.16.10.11 ipv4.method manual ipv6.method disabled
nmcli con up ens19
hostnamectl set-hostname bastion.lab.local
```

### Interface admin (`vmbr0` — souvent `ens18`)

Laisser en **DHCP** (réseau maison) pour Internet et mises à jour :

```bash
nmcli con mod ens18 ipv4.method auto
nmcli con up ens18
```

Vérifier Internet :

```bash
ping -c 2 registry.redhat.io
curl -I https://mirror.openshift.com
```

## 3. Repo DVD + paquets (phase install)

Sur `vmbr1` seul, utiliser le DVD — [rhel/dvd-repo.md](../rhel/dvd-repo.md).

Avec Internet via `vmbr0`, enregistrement Red Hat ou DVD au choix.

```bash
sudo dnf install -y podman skopeo jq git bind-utils tar
```

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

## 7. Piste RC 5 (optionnel, répertoire séparé)

```bash
mkdir -p ~/ocp-5-rc/bin && cd ~/ocp-5-rc/bin
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
tar xzf openshift-client-linux-*.tar.gz
tar xzf openshift-install-linux-*.tar.gz
export PATH=~/ocp-5-rc/bin:$PATH
```

## 8. Prochaine action : mirror OCP

Voir [mirror/README.md](../mirror/README.md) — pousser les images vers :

- GA : `registry.lab.local:5000/ocp4-422`
- RC : `registry.lab.local:5000/ocp5-rc`

## Accès SSH depuis le Mac

Une fois la bastion créée, SSH **direct** (sans ProxyJump) :

```bash
ssh bernard@<IP-bastion-LAN>
```

Puis depuis la bastion :

```bash
ssh bernard@172.16.10.20   # registry
dig @172.16.10.11 registry.lab.local
```

## Progression

- [ ] VM créée (2 NICs)
- [ ] Réseau lab `172.16.10.10` + admin Internet
- [ ] `oc` + `openshift-install` 4.22.12
- [ ] Pull secret + CA registry
- [ ] `oc mirror` vers registry lab

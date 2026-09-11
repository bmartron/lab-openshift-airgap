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

Avec deux interfaces, NetworkManager injecte le DNS maison (`192.168.1.1`) **avant** le DNS lab.
`dig @172.16.10.11 registry.lab.local` fonctionne, mais `curl https://registry.lab.local` échoue.

**Fix validé** — désactiver le DNS auto sur `ens18`, garder le DNS lab sur `ens19` :

```bash
sudo nmcli con mod ens18 ipv4.ignore-auto-dns yes
sudo nmcli con mod ens19 ipv4.dns 172.16.10.11
sudo nmcli con mod ens19 ipv4.dns-search lab.local
sudo nmcli con up ens18
sudo nmcli con up ens19

cat /etc/resolv.conf
dig registry.lab.local +short
curl --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog
```

| Symptôme | Cause | Action |
|----------|-------|--------|
| `Insufficient privileges` sur `nmcli` | Pas de `sudo` | Préfixer avec `sudo` |
| `resolvectl` : *not activatable* | `systemd-resolved` inactif sur RHEL | Utiliser NetworkManager (ci-dessus) |
| `dig @172.16.10.11` OK mais pas `dig registry.lab.local` | DNS maison en premier dans `resolv.conf` | `ipv4.ignore-auto-dns` sur `ens18` |

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

Installer la CA pour `oc mirror`, `curl` et Podman :

```bash
sudo mkdir -p /etc/containers/certs.d/registry.lab.local:5000
sudo cp ~/lab/ca.crt /etc/containers/certs.d/registry.lab.local:5000/ca.crt

sudo cp ~/lab/ca.crt /etc/pki/ca-trust/source/anchors/registry-lab.crt
sudo update-ca-trust

curl --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog
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

- [x] VM créée (2 NICs)
- [x] Réseau lab `172.16.10.10` + admin Internet
- [x] DNS lab (`*.lab.local` via NetworkManager)
- [x] `oc` + `openshift-install` 4.22.12
- [x] CA registry (`~/lab/ca.crt` + trust système)
- [ ] Pull secret (`~/lab/pull-secret.txt`)
- [ ] `oc mirror` vers registry lab

→ Prochaine étape : [mirror](../mirror/README.md)

# VM Bastion — RHEL 10

Poste d'orchestration du lab : outils OpenShift, mirror, génération ISO agent.

## Spécifications VM (Proxmox)

| Paramètre | Valeur |
|-----------|--------|
| Nom | `bastion` |
| OS | **RHEL 10** (Workstation ou Server minimal) |
| vCPU | 2 |
| RAM | 8 Go |
| Disque | 40 Go (NFS) |
| NIC 0 | `vmbr0` — admin / Internet (phase préparation) |
| NIC 1 | `vmbr1` — lab air-gap |
| IP lab | `172.16.10.10/24` |
| Hostname | `bastion.lab.local` |

## Paquets de base

Repo DVD local (VM isolée) — voir [rhel/dvd-repo.md](../rhel/dvd-repo.md).

```bash
sudo dnf install -y podman skopeo jq git bind-utils
```

## Installer oc / openshift-install (piste GA)

```bash
source versions.env   # OCP_GA_VERSION=4.22.12

cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_GA_VERSION}/openshift-client-linux-${OCP_GA_VERSION}.tar.gz
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_GA_VERSION}/openshift-install-linux-${OCP_GA_VERSION}.tar.gz

tar xzf openshift-client-linux-${OCP_GA_VERSION}.tar.gz -C /usr/local/bin oc kubectl
tar xzf openshift-install-linux-${OCP_GA_VERSION}.tar.gz -C /usr/local/bin openshift-install

oc version
openshift-install version
```

## Installer oc / openshift-install (piste RC 5)

Utiliser un répertoire séparé pour ne pas écraser les binaires GA :

```bash
mkdir -p ~/ocp-5-rc/bin
cd ~/ocp-5-rc/bin

oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
tar xzf openshift-client-linux-*.tar.gz
tar xzf openshift-install-linux-*.tar.gz

export PATH=~/ocp-5-rc/bin:$PATH
openshift-install version
```

## Réseau (interface lab)

```bash
NM_DEV=ens19   # 2e NIC — adapter

nmcli con mod "$NM_DEV" ipv4.addresses 172.16.10.10/24
nmcli con mod "$NM_DEV" ipv4.gateway 172.16.10.1
nmcli con mod "$NM_DEV" ipv4.dns 172.16.10.11
nmcli con mod "$NM_DEV" ipv4.method manual
nmcli con up "$NM_DEV"
```

## Répertoires de travail

```bash
mkdir -p ~/lab/{4.22-ga,5-rc}
```

Chaque piste utilise son propre répertoire d'install (`--dir`) avec `install-config.yaml` et `agent-config.yaml` dédiés.

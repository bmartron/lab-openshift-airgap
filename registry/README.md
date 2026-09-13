# Mirror Registry

Registry local pour l'installation air-gap d'OpenShift.

## Quel registry utiliser ?

| Solution | Lab air-gap | Commentaire |
|----------|-------------|-------------|
| **`registry:2`** (upstream) | **Recommandé** | Image Docker Hub — simple, suffisant pour `oc-mirror` |
| Red Hat **mirror-registry** (produit) | Non utilisé | Pas requis pour ce lab |

Ce lab utilise **`registry:2`** dans **Podman** sur RHEL 10.

## Spécifications VM

| Paramètre | Valeur |
|-----------|--------|
| Nom | `registry` |
| OS | RHEL 10 minimal |
| vCPU | 2 |
| RAM | 4–8 Go |
| Disque | **150 Go** sur la VM (données sous `/opt/registry` ou LV dédié) |
| NIC | `vmbr1` |
| IP | `172.16.10.20/24` |
| DNS | `172.16.10.11` |
| Hostname | `registry.lab.local` |

### Partitionnement à l’installation (important)

L’**autopartition RHEL** répartit souvent le disque en **`/` ~70 Go** + **`/home` ~70 Go**. Pour une VM **uniquement registry**, c’est inadapté : le mirror OCP + opérateurs remplit **`/`** et `oc-mirror` renvoie des **HTTP 500** (disque plein) alors que **`/home` reste vide**.

À l’install (Anaconda / kickstart), viser l’un de ces schémas sur **150 Go** :

| Approche | Layout suggéré |
|----------|----------------|
| **Simple** | Une grosse partition **`/`** (~140 Go), **pas** de `/home` séparé (ou `/home` 1–4 Go) |
| **Propre** | LVM : `rhel-root` **10–20 Go** (OS) + LV **`registry`** ~**130 Go** monté sur **`/opt/registry`** |
| **Swap** | 2–4 Go suffisent (pas 8 Go si chaque Go compte) |

Exemple kickstart (idée — à adapter) : tout le VG dans `rhel-root` sauf boot/efi/swap.

> VM déjà installée avec `/` plein et `/home` libre : déplacer les données vers `/home/registry` (contournement) ou réinstaller avec le bon layout (propre). Voir § Dépannage ci-dessous.

## 1. Créer la VM + réseau

```bash
nmcli con mod ens18 ipv4.addresses 172.16.10.20/24 ipv4.gateway 172.16.10.1 \
  ipv4.dns 172.16.10.11 ipv4.method manual ipv6.method disabled
nmcli con up ens18
hostnamectl set-hostname registry.lab.local
```

## 2. Repo DVD + paquets

Voir [rhel/dvd-repo.md](../rhel/dvd-repo.md).

```bash
sudo dnf install -y podman openssl
```

## 3. Image registry:2 amd64 — Mac → VM

> Mac Apple Silicon tire `arm64` par défaut — les VMs Proxmox sont **amd64**.

Sur le **Mac** :

```bash
podman pull --platform linux/amd64 docker.io/library/registry:2
podman save -o ~/Downloads/registry2-amd64.tar docker.io/library/registry:2
```

Transfert — [proxmox/access.md](../proxmox/access.md) :

```bash
scp -o ProxyJump=root@192.168.1.147 \
  "/Users/bmartron/Downloads/registry2-amd64.tar" \
  bernard@172.16.10.20:/tmp/registry2-amd64.tar
```

Sur la VM registry (**sudo** — même storage root) :

```bash
sudo podman load -i /tmp/registry2-amd64.tar
sudo podman images | grep registry
```

## 4. Certificats TLS + démarrage

```bash
sudo mkdir -p /opt/registry/{data,certs}
cd /opt/registry/certs

sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 \
  -out ca.crt -subj "/CN=Lab CA"
sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key \
  -out registry.csr -subj "/CN=registry.lab.local" \
  -addext "subjectAltName=DNS:registry.lab.local,DNS:registry"
sudo openssl x509 -req -days 3650 -sha256 -in registry.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out registry.crt \
  -copy_extensions copyall

sudo podman run -d --name ocp-registry --restart=always --pull=never \
  -p 5000:5000 \
  -v /opt/registry/data:/var/lib/registry:Z \
  -v /opt/registry/certs:/certs:Z \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  docker.io/library/registry:2
```

> `--pull=never` : obligatoire sur réseau isolé (pas d'accès Docker Hub).

## 5. Vérification

Sur la VM :

```bash
curl -k https://localhost:5000/v2/_catalog
# → {"repositories":[]}
```

Depuis **Proxmox** (avec `/etc/hosts` — voir [proxmox/hosts.lab.example](../proxmox/hosts.lab.example)) :

```bash
curl -k https://registry.lab.local:5000/v2/_catalog
```

## Certificat pour OpenShift

```bash
sudo cat /opt/registry/certs/ca.crt
```

Depuis le **Mac** (sans sudo interactif si `ca.crt` est en `0644` après Ansible) :

```bash
scp -o ProxyJump=root@192.168.1.147 \
  bernard@172.16.10.20:/opt/registry/certs/ca.crt \
  ~/Downloads/registry-ca.crt
```

Sinon, avec mot de passe sudo :

```bash
ssh -t -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20 \
  'sudo cat /opt/registry/certs/ca.crt' > ~/Downloads/registry-ca.crt
```

Sur la registry (une fois) :

```bash
sudo chmod 644 /opt/registry/certs/ca.crt
```

→ `additionalTrustBundle` dans les `install-config.yaml`. **Ne pas** committer les `.key`.

## Dépannage

| Symptôme | Solution |
|----------|----------|
| `openssl: command not found` | `sudo dnf install -y openssl` |
| `platform arm64 vs amd64` | Re-tirer avec `--platform linux/amd64` sur Mac |
| Podman pull Docker Hub | `sudo podman load` + `--pull=never` |
| Proxmox ne résout pas les noms | `/etc/hosts` — pas le DNS lab dans resolv.conf |
| `oc-mirror` : *legacy Common Name, use SANs* | Cert sans SAN | Régénérer `registry.crt` avec `subjectAltName` (voir §4) |
| Push mirror **HTTP 500** | **`/` plein** (souvent `/opt/registry/data`) | `df -h /` ; agrandir LV ou données sur LV `/home` / réinstaller avec § Partitionnement |
| Disque 150 Go mais `/` = 70 Go | Layout RHEL par défaut | `lsblk` + `lvs` : étendre `rhel-root` seulement si **PFree** ; sinon déplacer registry ou repartitionner |

## Progression

- [x] VM + réseau `172.16.10.20`
- [x] Repo DVD + podman + openssl
- [x] Image `registry:2` amd64 chargée
- [x] Registry HTTPS actif
- [x] `curl -k` OK (VM + Proxmox via hosts)

→ Prochaine étape : [bastion](../bastion/README.md)

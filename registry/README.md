# Mirror Registry

Registry local pour l'installation air-gap d'OpenShift.

## Quel registry utiliser ?

| Solution | Lab air-gap | Commentaire |
|----------|-------------|-------------|
| **`registry:2`** (upstream) | **Recommandé** | Image Docker Hub — simple, suffisant pour `oc mirror` |
| Red Hat **mirror-registry** (produit) | Non utilisé | Pas requis pour ce lab |
| **Quay** | Non utilisé | Plus lourd |

Ce lab utilise **`registry:2`** dans **Podman** sur RHEL 10.

## Spécifications VM

| Paramètre | Valeur |
|-----------|--------|
| Nom | `registry` |
| OS | RHEL 10 minimal |
| vCPU | 2 |
| RAM | 4–8 Go |
| Disque | 150 Go (NFS) |
| NIC | `vmbr1` |
| IP | `172.16.10.20/24` |
| DNS | `172.16.10.11` |
| Hostname | `registry.lab.local` |

Accès SSH : [proxmox/access.md](../proxmox/access.md) — `ProxyJump=root@192.168.1.147`.

## 1. Créer la VM + réseau

```bash
nmcli con mod ens18 ipv4.addresses 172.16.10.20/24 ipv4.gateway 172.16.10.1 \
  ipv4.dns 172.16.10.11 ipv4.method manual ipv6.method disabled
nmcli con up ens18
hostnamectl set-hostname registry.lab.local
```

## 2. Repo DVD + podman

Voir [rhel/dvd-repo.md](../rhel/dvd-repo.md) — créer le repo avec `sudo tee` (le fichier n'est pas sur la VM par défaut).

```bash
sudo dnf install -y podman
```

## 3. Image registry:2 — Mac → VM registry

### Sur le Mac (Podman Desktop)

1. Créer la **Podman Machine** (obligatoire sur Mac)
2. Télécharger l'image :

```bash
podman pull docker.io/library/registry:2
podman save -o ~/Downloads/registry2.tar docker.io/library/registry:2
```

### Transfert scp (depuis le Mac)

```bash
scp -o ProxyJump=root@192.168.1.147 \
  "/Users/bmartron/Downloads/registry2.tar" \
  bernard@172.16.10.20:/tmp/registry2.tar
```

### Sur la VM registry

```bash
podman load -i /tmp/registry2.tar
podman images | grep registry
```

## 4. Certificats TLS + démarrage

```bash
sudo mkdir -p /opt/registry/{data,certs}
cd /opt/registry/certs

sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 \
  -out ca.crt -subj "/CN=Lab CA"
sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key \
  -out registry.csr -subj "/CN=registry.lab.local"
sudo openssl x509 -req -days 3650 -sha256 -in registry.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out registry.crt

sudo podman run -d --name ocp-registry --restart=always \
  -p 5000:5000 \
  -v /opt/registry/data:/var/lib/registry:Z \
  -v /opt/registry/certs:/certs:Z \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2
```

## 5. Vérification

Depuis **Proxmox** :

```bash
curl -k https://registry.lab.local:5000/v2/_catalog
# → {"repositories":[]}
```

## Certificat pour OpenShift

Copier `ca.crt` dans `additionalTrustBundle` des `install-config.yaml` :

```bash
sudo cat /opt/registry/certs/ca.crt
```

**Ne pas** committer `ca.key` ni `registry.key`.

## Progression

- [x] VM créée + réseau `172.16.10.20`
- [x] Repo DVD + podman
- [x] Image `registry:2` transférée (`scp` via ProxyJump)
- [ ] Registry HTTPS actif
- [ ] `curl -k` OK depuis Proxmox

→ Prochaine étape : [bastion](../bastion/README.md)

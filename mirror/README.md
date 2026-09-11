# Miroir des images OpenShift (air-gap)

Deux pistes séparées — voir [docs/versions.md](../docs/versions.md).

| Piste | Version | Config mirror | Namespace registry |
|-------|---------|---------------|-------------------|
| **GA** | 4.22.12 | [imageset-config-4.22.yaml.example](imageset-config-4.22.yaml.example) | `ocp4-422` |
| **RC 5** | 5.0.0-ec.6 | [imageset-config-5-rc.yaml.example](imageset-config-5-rc.yaml.example) | `ocp5-rc` |

## Phase 1 — Avec Internet (bastion `ens18` / vmbr0)

Prérequis sur la bastion : DNS lab OK, CA registry installée — voir [bastion/README.md](../bastion/README.md).

```bash
cp versions.env.example versions.env
source versions.env
```

### Trust TLS registry (CA auto-signée)

À faire une fois sur la bastion avant le mirror :

```bash
sudo mkdir -p /etc/containers/certs.d/registry.lab.local:5000
sudo cp ~/lab/ca.crt /etc/containers/certs.d/registry.lab.local:5000/ca.crt

sudo cp ~/lab/ca.crt /etc/pki/ca-trust/source/anchors/registry-lab.crt
sudo update-ca-trust

curl --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog
# → {"repositories":[]}
```

> Le certificat registry doit inclure des **SAN** (`DNS:registry.lab.local`) — voir [registry/README.md](../registry/README.md).

### Pull secret

Télécharger depuis [cloud.redhat.com/openshift/install/pull-secret](https://cloud.redhat.com/openshift/install/pull-secret).

Depuis le **Mac** :

```bash
scp ~/Downloads/pull-secret.txt bernard@<IP-bastion-LAN>:~/lab/pull-secret.txt
```

### Installer oc-mirror v2

```bash
export OCP_VERSION=4.22.12
cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/oc-mirror.tar.gz
tar xzf oc-mirror.tar.gz
sudo mv oc-mirror /usr/local/bin/
sudo chmod +x /usr/local/bin/oc-mirror
```

### Piste GA — oc mirror v2 (recommandé)

```bash
mkdir -p ~/lab/4.22-ga
cd ~/lab/4.22-ga
cp mirror/imageset-config-4.22.yaml.example imageset-config.yaml

oc mirror -c imageset-config.yaml \
  --workspace file://$HOME/lab/4.22-ga/workspace \
  docker://registry.lab.local:5000/ocp4-422 \
  --v2 --src-pull-secret ~/lab/pull-secret.txt
```

Durée observée en lab : **~7 min** (selon bande passante).

### Vérification post-mirror

```bash
curl -s --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog | jq '.repositories | length'
# Attendu : 2 repos (release + release-images)

ls ~/lab/4.22-ga/workspace/working-dir/cluster-resources/
# idms-oc-mirror.yaml  itms-oc-mirror.yaml  signature-configmap.*

# Chemins exacts pour install-config.yaml
grep -A2 mirrors ~/lab/4.22-ga/workspace/working-dir/cluster-resources/itms-oc-mirror.yaml
```

Chemins à reporter dans `install-config.yaml` :

```yaml
imageContentSources:
- source: quay.io/openshift-release-dev/ocp-release
  mirrors:
  - registry.lab.local:5000/ocp4-422/openshift/release-images
- source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
  mirrors:
  - registry.lab.local:5000/ocp4-422/openshift/release
```

### Piste GA — release mirror (alternative)

```bash
oc adm release mirror \
  --from=quay.io/openshift-release-dev/ocp-release:${OCP_GA_RELEASE} \
  --to=docker://registry.lab.local:5000/ocp4-422 \
  --to-release-image=registry.lab.local:5000/ocp4-422/release:${OCP_GA_RELEASE}
```

### Piste RC 5 — mirror

```bash
oc adm release mirror \
  --from=quay.io/openshift-release-dev/ocp-release:${OCP_RC_VERSION}-x86_64 \
  --to=docker://registry.lab.local:5000/ocp5-rc \
  --to-release-image=registry.lab.local:5000/ocp5-rc/release:${OCP_RC_VERSION}
```

> Les builds RC (`ec.X`) sont disponibles via `quay.io/openshift-release-dev/ocp-release`. Vérifier le stream [5-dev-preview](https://amd64.ocp.releases.ci.openshift.org/#5-dev-preview).

## Phase 2 — Vérification air-gap

Depuis la bastion sur `vmbr1` uniquement :

```bash
oc adm release info \
  registry.lab.local:5000/ocp4-422/openshift/release-images:4.22.12-x86_64
```

## Espace disque

Prévoir **≥ 120 Go par piste** sur le volume registry (GA + RC = ~240 Go si les deux sont miroirées en même temps).  
Observé en lab GA 4.22.12 : **~22 Go** sur `/opt/registry/data`.

## Opérateurs air-gap (phase ultérieure)

Pour Virt, ODF, etc. : ajouter des catalogues dans `imageset-config.yaml` puis relancer `oc mirror` vers le même namespace ou un namespace dédié.

## Dépannage

| Symptôme | Cause probable | Action |
|----------|----------------|--------|
| `error: unknown command "mirror"` | Plugin oc-mirror absent | Installer `oc-mirror` binaire (ci-dessus) |
| `x509: ... use SANs instead` | Cert registry sans SAN | Regénérer cert — [registry/README.md](../registry/README.md) |
| `x509: certificate signed by unknown authority` | CA non trustée | Section trust TLS ci-dessus |
| `Could not resolve host: registry.lab.local` | DNS maison prioritaire | [bastion/README.md](../bastion/README.md) § Résolution DNS lab |
| `Could not resolve host: mirror.openshift.com` | DNS lab seul | `/etc/hosts` lab + DNS maison sur `ens18` |
| `unauthorized` sur `registry.redhat.io` | Pull secret manquant / invalide | Vérifier `~/lab/pull-secret.txt` |
| `manifest unknown` sur release locale | Mauvais chemin image | Utiliser chemins `ocp4-422/openshift/release-images` (pas `quay.io/...` dans le tag) |

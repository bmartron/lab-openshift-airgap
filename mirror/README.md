# Miroir des images OpenShift (air-gap)

Deux pistes séparées — voir [docs/versions.md](../docs/versions.md).

| Piste | Version | Config mirror | Namespace registry |
|-------|---------|---------------|-------------------|
| **GA** | 4.22.12 | [imageset-config-4.22.yaml.example](imageset-config-4.22.yaml.example) (GitOps) | `ocp4-422` |
| **GA plateforme seule** | 4.22.12 | [imageset-config-4.22-platform-only.yaml.example](imageset-config-4.22-platform-only.yaml.example) | `ocp4-422` |
| **GA + Virtualization** | 4.22.12 | [imageset-config-4.22-virtualization.yaml.example](imageset-config-4.22-virtualization.yaml.example) | `ocp4-422` |
| **RC 5** | 5.0.0-ec.6 | [imageset-config-5-rc.yaml.example](imageset-config-5-rc.yaml.example) | `ocp5-rc` |

### Où exécuter quoi (lab NUC)

| Machine | IP | Rôle mirror |
|---------|-----|-------------|
| **Mac** | réseau maison | `scp` fichiers → bastion ; édition du dépôt git |
| **Bastion** | **`192.168.1.144`** (`vmbr0`) | SSH depuis le Mac ; `oc-mirror`, Internet, `~/lab/` |
| **Bastion** | **`172.16.10.10`** (`vmbr1`) | Accès lab (DNS `172.16.10.11`, registry) — pas pour `scp` depuis le Mac |
| **Registry** | **`172.16.10.20`** | Cible push `registry.lab.local:5000` ; données sur `/opt/registry` |
| **Proxmox** | **`192.168.1.147`** | Jump SSH vers `172.16.10.x` si besoin |

## Phase 1 — Avec Internet (bastion **`192.168.1.144`**, NIC `vmbr0`)

Toutes les commandes ci-dessous : **`ssh bernard@192.168.1.144`** sauf `scp` indiqué **Mac → 192.168.1.144**.

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
scp ~/Downloads/pull-secret.txt bernard@192.168.1.144:~/lab/pull-secret.txt
```

### Installer oc-mirror v2

Sur la **bastion `192.168.1.144`** :

```bash
export OCP_VERSION=4.22.12
cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/oc-mirror.tar.gz
tar xzf oc-mirror.tar.gz
sudo mv oc-mirror /usr/local/bin/
sudo chmod +x /usr/local/bin/oc-mirror
```

### Choisir l’imageset GA 4.22

| Besoin | Fichier exemple |
|--------|-----------------|
| SNO sans opérateur | `imageset-config-4.22-platform-only.yaml.example` |
| GitOps (Argo CD) | `imageset-config-4.22.yaml.example` |
| OpenShift Virtualization | `imageset-config-4.22-virtualization.yaml.example` |

**Mac → bastion `192.168.1.144`** (ex. Virtualization) :

```bash
scp /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/mirror/imageset-config-4.22-virtualization.yaml.example \
  bernard@192.168.1.144:/home/bernard/lab/4.22-ga/imageset-config.yaml
```

### Piste GA — oc-mirror v2 (recommandé)

Sur la **bastion `192.168.1.144`** :

```bash
mkdir -p ~/lab/4.22-ga
cd ~/lab/4.22-ga
# ou : cp depuis le dépôt cloné sur la bastion
cp ~/Projet-Airgap-deploy/mirror/imageset-config-4.22.yaml.example imageset-config.yaml

oc-mirror -c imageset-config.yaml \
  --workspace file://$HOME/lab/4.22-ga/workspace \
  docker://registry.lab.local:5000/ocp4-422 \
  --authfile ~/lab/pull-secret.txt --dest-tls-verify=false --v2
```

Durée observée en lab : **~7 min** (plateforme seule, une version 4.22.12).

**Opérateurs** : toujours **épingler** `channels` + `minVersion` / `maxVersion` identiques. Utiliser le **nom de channel du catalogue** (défaut du package), pas un nom inventé :

| Package | Channel à utiliser (lab 4.22) |
|---------|-------------------------------|
| `openshift-gitops-operator` | `gitops-1.16` (pas `latest`) |
| `kubevirt-hyperconverged` | **`stable`** (pas `stable-4.22`) |

Erreur *default channel "stable" was filtered out* → mauvais channel dans `imageset-config.yaml` (ex. `stable-4.22` au lieu de `stable`).

Sur la **bastion `192.168.1.144`** (Internet) :

```bash
oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.22 \
  --package=kubevirt-hyperconverged \
  --authfile ~/lab/pull-secret.txt --v2
```

Pour **kubevirt-hyperconverged**, `minVersion` / `maxVersion` = semver du **HEAD** du canal `stable` dans `list operators` (ex. `4.22.9`), **pas** le z-stream OCP (`4.22.12`).

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

## Opérateurs air-gap

GitOps ou Virtualization : un fichier exemple dédié (voir tableau ci-dessus). Push vers **registry `172.16.10.20`** (`docker://registry.lab.local:5000/ocp4-422`). Virtualization = mirror **plus gros** + [nested virt](../proxmox/network.md) sur le cluster.

### Supprimer puis re-mirror GitOps (version épinglée)

Si un premier mirror a tiré **toutes** les versions GitOps (ex. **187 operator images**), libérer la registry avant de re-mirror :

1. **Espace disque** sur la VM registry (données registry, pas seulement `/` plein).
2. Sur la **bastion**, workspace du mirror opérateurs (celui utilisé pour le premier run) :

```bash
cd ~/lab/4.22-ga
cp delete-openshift-gitops.yaml.example delete-gitops.yaml   # depuis le dépôt, ou recopier le contenu

# Phase delete 1 — génère la liste (relire le YAML généré avant d’exécuter)
oc-mirror delete -c delete-gitops.yaml \
  --workspace file://$HOME/lab/4.22-ga/workspace-operators \
  --generate --delete-id gitops-full \
  docker://registry.lab.local:5000/ocp4-422 \
  --authfile ~/lab/pull-secret.txt --dest-tls-verify=false --v2

# Phase delete 2 — exécution (irréversible sur la registry)
oc-mirror delete \
  --delete-yaml-file $HOME/lab/4.22-ga/workspace-operators/working-dir/delete/delete-images-gitops-full.yaml \
  docker://registry.lab.local:5000/ocp4-422 \
  --authfile ~/lab/pull-secret.txt --dest-tls-verify=false --v2
```

> Le chemin exact de `delete-images-*.yaml` est affiché en fin de phase `--generate`. Adapter si le nom diffère.

3. **Garbage collection** sur la VM **registry** (sinon les blobs restent sur disque) :

```bash
sudo podman exec ocp-registry registry garbage-collect /etc/docker/registry/config.yml
```

4. Mettre à jour `imageset-config.yaml` avec **channels** + **minVersion** / **maxVersion** (voir [imageset-config-4.22.yaml.example](imageset-config-4.22.yaml.example)).

5. Re-mirror :

```bash
oc-mirror -c imageset-config.yaml \
  --workspace file://$HOME/lab/4.22-ga/workspace-operators \
  docker://registry.lab.local:5000/ocp4-422 \
  --authfile ~/lab/pull-secret.txt --dest-tls-verify=false --v2
```

6. Si le cluster avait déjà des **IDMS/ITMS** opérateurs appliqués : `oc apply -f workspace-operators/.../cluster-resources/` après le nouveau mirror.

**Ne pas** supprimer la section `platform` dans un delete : les images **4.22.12** du SNO en dépendent. Le catalogue `redhat-operator-index` n’est en général **pas** supprimé tant que seul le package GitOps est listé (comportement voulu).

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
| Push mirror **HTTP 500** | Registry disque plein | [registry/README.md](../registry/README.md) — 2e disque `/opt/registry` |

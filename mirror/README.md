# Miroir des images OpenShift (air-gap)

## Phase 1 — Avec Internet (bastion eth0)

### Prérequis

```bash
# Versions alignées — exemple 4.16
export OCP_VERSION=4.16.0
export OCP_RELEASE=${OCP_VERSION}-x86_64

# Installer oc et openshift-install depuis mirror.openshift.com
# ou via le canal Red Hat approprié
```

### Pull secret

Télécharger depuis [cloud.redhat.com/openshift/install/pull-secret](https://cloud.redhat.com/openshift/install/pull-secret) et sauver en `pull-secret.txt` (racine du projet ou `openshift/` — **non versionné**).

### Méthode oc mirror (recommandée)

```bash
# Créer ImageSetConfiguration — voir imageset-config.yaml.example
oc mirror --config=imageset-config.yaml docker://registry.lab.local:5000
```

> En phase préparation, le registry peut être accessible via tunnel ou IP temporaire.
> Une fois les images poussées, couper l'accès Internet pour la phase install.

### Méthode classique (release mirror)

```bash
oc adm release mirror \
  --from=quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE} \
  --to=docker://registry.lab.local:5000/ocp4 \
  --to-release-image=registry.lab.local:5000/ocp4/release:${OCP_RELEASE}
```

## Phase 2 — Vérification air-gap

Depuis la bastion sur `vmbr1` uniquement :

```bash
oc adm release info registry.lab.local:5000/ocp4/release:${OCP_RELEASE} \
  --insecure=false \
  --icsp-file=/path/to/icsp.yaml
```

## Espace disque

Prévoir **≥ 100 Go** sur le volume registry pour une release + operators de base.

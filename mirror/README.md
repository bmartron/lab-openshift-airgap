# Miroir des images OpenShift (air-gap)

Deux pistes séparées — voir [docs/versions.md](../docs/versions.md).

| Piste | Version | Config mirror | Namespace registry |
|-------|---------|---------------|-------------------|
| **GA** | 4.22.12 | [imageset-config-4.22.yaml.example](imageset-config-4.22.yaml.example) | `ocp4-422` |
| **RC 5** | 5.0.0-ec.6 | [imageset-config-5-rc.yaml.example](imageset-config-5-rc.yaml.example) | `ocp5-rc` |

## Phase 1 — Avec Internet (bastion eth0)

```bash
cp versions.env.example versions.env
source versions.env
```

### Pull secret

Télécharger depuis [cloud.redhat.com/openshift/install/pull-secret](https://cloud.redhat.com/openshift/install/pull-secret) → `pull-secret.txt` (**non versionné**).

### Piste GA — oc mirror (recommandé)

```bash
oc mirror --config=imageset-config-4.22.yaml docker://registry.lab.local:5000/ocp4-422
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
# GA
oc adm release info registry.lab.local:5000/ocp4-422/release:4.22.12-x86_64

# RC 5
oc adm release info registry.lab.local:5000/ocp5-rc/release:5.0.0-ec.6-x86_64
```

## Espace disque

Prévoir **≥ 120 Go par piste** sur le volume registry (GA + RC = ~240 Go si les deux sont miroirées en même temps).

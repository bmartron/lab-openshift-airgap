# OpenShift 5 RC — installation agent-based (air-gap)

| Paramètre | Valeur |
|-----------|--------|
| Version | **5.0.0-ec.6** (Release Candidate / dev-preview) |
| Kubernetes | 1.36 (attendu — confirmer via release notes) |
| Cluster name | `ocp5` |
| Base domain | `ocp5.lab.local` |
| SNO IP | `172.16.10.110` |
| Mirror registry | `registry.lab.local:5000/ocp5-rc` |

> **Attention** : build pré-GA, non supporté en production. Stream : [5-dev-preview](https://amd64.ocp.releases.ci.openshift.org/#5-dev-preview). Épingler un tag `ec.X` précis.

## DNS requis

```
api.ocp5.lab.local        → 172.16.10.110
api-int.ocp5.lab.local    → 172.16.10.110
*.apps.ocp5.lab.local     → 172.16.10.110
```

## Mirror RC (phase préparation avec Internet)

```bash
export OCP_RC=5.0.0-ec.6

oc adm release mirror \
  --from=quay.io/openshift-release-dev/ocp-release:${OCP_RC}-x86_64 \
  --to=docker://registry.lab.local:5000/ocp5-rc \
  --to-release-image=registry.lab.local:5000/ocp5-rc/release:${OCP_RC}
```

Ou `oc mirror` avec [imageset-config-5-rc.yaml.example](../../mirror/imageset-config-5-rc.yaml.example).

## Binaires installateur

```bash
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
```

## Installation

```bash
export PATH=~/ocp-5-rc/bin:$PATH
mkdir -p ~/lab/5-rc && cd ~/lab/5-rc
cp install-config.yaml.example install-config.yaml
cp agent-config.yaml.example agent-config.yaml

openshift-install agent create image --dir .
openshift-install agent wait-for install-complete --dir . --log-level debug
```

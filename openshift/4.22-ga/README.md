# OpenShift 4.22 GA — installation agent-based (air-gap)

| Paramètre | Valeur |
|-----------|--------|
| Version | **4.22.12** (z-stream GA — vérifier la dernière sur console.redhat.com) |
| Kubernetes | 1.35 |
| Cluster name | `ocp422` |
| Base domain | `ocp422.lab.local` |
| SNO IP | `172.16.10.100` |
| Mirror registry | `registry.lab.local:5000/ocp4-422` |

## DNS requis

```
api.ocp422.lab.local        → 172.16.10.100
api-int.ocp422.lab.local    → 172.16.10.100
*.apps.ocp422.lab.local     → 172.16.10.100
```

## Installation

```bash
mkdir -p ~/lab/4.22-ga && cd ~/lab/4.22-ga
cp install-config.yaml.example install-config.yaml
cp agent-config.yaml.example agent-config.yaml
# Éditer pull secret, sshKey, CA, MAC

openshift-install agent create image --dir .
# Monter l'ISO sur la VM ocp-sno (172.16.10.100)
openshift-install agent wait-for install-complete --dir . --log-level debug
```

Voir aussi [mirror/README.md](../../mirror/README.md) pour le miroir des images.

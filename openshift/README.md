# Installation OpenShift — Agent-based (air-gap)

## Prérequis

- [ ] DNS opérationnel sur `172.16.10.11`
- [ ] Registry miroir sur `registry.lab.local:5000`
- [ ] Images miroir poussées — voir [mirror/README.md](../mirror/README.md)
- [ ] `oc` et `openshift-install` installés sur la bastion (même version OCP)

## Fichiers

| Fichier | Description |
|---------|-------------|
| `install-config.yaml.example` | Config cluster (base de domaine, mirrors, trust bundle) |
| `agent-config.yaml.example` | Config agent (hosts, réseau statique, MAC) |

## Utilisation

```bash
# Copier et adapter les exemples
cp install-config.yaml.example install-config.yaml
cp agent-config.yaml.example agent-config.yaml

# Ajouter le pull secret (fichier local, non versionné)
# Éditer install-config.yaml avec votre sshKey et additionalTrustBundle

# Générer l'ISO agent
openshift-install agent create image --dir .

# Monter l'ISO sur la VM ocp-sno (Proxmox UI ou CLI)
# Puis attendre la fin de l'installation
openshift-install agent wait-for install-complete --dir . --log-level debug
```

## Après installation

```bash
export KUBECONFIG=$(pwd)/auth/kubeconfig
oc get nodes
oc get co
```

## Notes

- Adapter le nom d'interface (`enp6s18`) et la MAC dans `agent-config.yaml` selon Proxmox.
- Le `rootDeviceHints` doit correspondre au disque de la VM (`/dev/vda` en VirtIO).

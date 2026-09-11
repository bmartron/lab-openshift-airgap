# Installation OpenShift — Agent-based (air-gap)

Deux pistes de déploiement :

| Piste | Version | Répertoire |
|-------|---------|------------|
| **GA** | OpenShift **4.22.12** | [4.22-ga/](4.22-ga/) |
| **RC 5** | OpenShift **5.0.0-ec.6** | [5-rc/](5-rc/) |

## Prérequis communs

- [ ] DNS opérationnel sur `172.16.10.11` — voir [dns/README.md](../dns/README.md)
- [ ] Registry miroir sur `registry.lab.local:5000`
- [ ] Images miroir poussées — voir [mirror/README.md](../mirror/README.md)
- [ ] Bastion RHEL 10 avec `oc` / `openshift-install` alignés sur la piste — voir [bastion/README.md](../bastion/README.md)

## Versions et variables

Voir [docs/versions.md](../docs/versions.md) et `versions.env.example`.

## Pièges courants (agent-based air-gap)

| Problème | Solution |
|----------|----------|
| `api.ocp422.ocp422.lab.local` | `baseDomain: lab.local` + `name: ocp422` |
| `/dev/not-found-by-hints` | `rootDeviceHints.deviceName: /dev/sda` (SCSI Proxmox) |
| `json: unknown field "additionalNtpServers"` | NTP dans `agent-config.yaml` uniquement |
| `apiVersion: v1` agent-config | Utiliser `v1beta1` |
| ISO non générée (état partiel) | `rm .openshift_install_state.json` + regénérer |
| Bootstrap bloqué, pas de bootkube | Vérifier disque d'install + wipe disque SNO |

Détail complet : [4.22-ga/README.md](4.22-ga/README.md)

## Fichiers legacy

Les anciens `install-config.yaml.example` et `agent-config.yaml.example` à la racine de ce dossier sont conservés pour référence — utiliser les répertoires versionnés `4.22-ga/` et `5-rc/`.

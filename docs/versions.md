# Versions du lab

## Stratégie double piste

Le lab supporte **deux environnements OpenShift** en parallèle (clusters et mirrors séparés) :

| Piste | Version OpenShift | Usage | Répertoire config |
|-------|-------------------|-------|-------------------|
| **GA** | **4.22.12** (Kubernetes 1.35) | Lab stable, formation install/day-2 | [openshift/4.22-ga/](../openshift/4.22-ga/) |
| **RC** | **5.0.0-ec.6** (Release Candidate) | Test OCP 5, préparation migration | [openshift/5-rc/](../openshift/5-rc/) |

> Vérifier les z-streams sur [console.redhat.com](https://console.redhat.com/openshift/downloads) et le stream [5-dev-preview](https://amd64.ocp.releases.ci.openshift.org/#5-dev-preview) pour les RC.

## OS des VMs infra

| VM | OS | Version |
|----|-----|---------|
| dns | RHEL | **10.x** (minimal) |
| registry | RHEL | **10.x** (minimal) |
| bastion | RHEL | **10.x** |
| nœuds OpenShift | **RHCOS** | Fourni par la release OCP (pas RHEL installé manuellement) |

## Alignement des binaires (bastion)

Les outils `oc` et `openshift-install` doivent correspondre **exactement** à la release du cluster :

```bash
# GA
export OCP_RELEASE=4.22.12-x86_64

# RC 5 (épingler le build ec précis)
export OCP_RELEASE=5.0.0-ec.6-x86_64
```

Téléchargement GA :

```bash
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.22.12/openshift-client-linux-4.22.12.tar.gz
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.22.12/openshift-install-linux-4.22.12.tar.gz
```

Téléchargement RC 5 :

```bash
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
```

## Registries miroir (séparation GA / RC)

| Piste | Chemin registry | Espace disque conseillé |
|-------|-----------------|----------------------|
| GA 4.22.12 | `registry.lab.local:5000/ocp4-422` | ≥ 120 Go |
| RC 5.0 | `registry.lab.local:5000/ocp5-rc` | ≥ 120 Go |

Ne pas mélanger les images GA et RC dans le même namespace registry.

## Clusters prévus

| Cluster | Base domain | API | Nœud SNO |
|---------|-------------|-----|----------|
| GA | `ocp422.lab.local` | `api.ocp422.lab.local` | `172.16.10.100` |
| RC 5 | `ocp5.lab.local` | `api.ocp5.lab.local` | `172.16.10.110` |

> Un seul cluster SNO actif à la fois si les ressources NUC sont limitées (64 Go RAM).

## Mise à jour des versions

1. Modifier [versions.env.example](../versions.env.example)
2. Mettre à jour les `imageset-config` dans `mirror/`
3. Régénérer les mirrors (`oc-mirror`) — voir [lab-alignment.md](lab-alignment.md)
4. Mettre à jour les DNS (wildcard `*.apps`)
5. Documenter dans [CHANGELOG.md](CHANGELOG.md)

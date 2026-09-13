# Alignement stack lab (audit)

Référence pour vérifier que dépôt, outils et infra correspondent. Dernière revue : alignée **Proxmox VE 9.2** + **OCP 4.22.12**.

## Infra

| Composant | Version / choix | Où c’est défini |
|-----------|-----------------|-----------------|
| Proxmox | **9.2.x** (ex. 9.2.18) | Hôte NUC |
| Terraform | ≥ 1.5 | Mac / bastion |
| Provider Proxmox | **telmate/proxmox 3.0.2-rc10** | [terraform/proxmox/versions.tf](../terraform/proxmox/versions.tf) + `.terraform.lock.hcl` |
| Token API | `root@pam!terraform`, **Privilege Separation : non** (lab) | Proxmox UI |
| PVE 9 | **Pas de `VM.Monitor`** dans les rôles custom | [terraform/README.md](../terraform/README.md) |
| Registry VM | scsi0 32G + scsi1 120G, `vmbr1`, ISO RHEL 10 | Terraform + [registry/README.md](../registry/README.md) |
| Données registry | `/opt/registry` sur **scsi1** (pas `/` + `/home` 50/50) | Install RHEL + [registry/README.md](../registry/README.md) § partitionnement |

## OpenShift GA (piste active)

| Élément | Valeur |
|---------|--------|
| Release | **4.22.12** |
| Mirror namespace | `ocp4-422` |
| SNO IP | `172.16.10.100` |
| Binaires bastion | `oc`, `openshift-install`, **`oc-mirror`** (binaire séparé, pas `oc mirror`) |
| Mirror pull auth | **`--authfile ~/lab/pull-secret.txt`** + `--dest-tls-verify=false` si CA lab |
| ImageSet | `apiVersion: mirror.openshift.io/v1alpha2` — **GitOps épinglé** (channel + min/max) |
| Delete GitOps | [mirror/delete-openshift-gitops.yaml.example](../mirror/delete-openshift-gitops.yaml.example) |
| Imageset Virtualization | [mirror/imageset-config-4.22-virtualization.yaml.example](../mirror/imageset-config-4.22-virtualization.yaml.example) |
| Delete Virtualization | [mirror/delete-kubevirt-hyperconverged.yaml.example](../mirror/delete-kubevirt-hyperconverged.yaml.example) |
| Bastion Mac (scp/ssh) | **`192.168.1.144`** — lab NIC **`172.16.10.10`** |

## Commandes à ne plus utiliser

| Obsolète | Remplacement |
|----------|----------------|
| `oc mirror -c ...` | `oc-mirror -c ...` |
| `--src-pull-secret` | `--authfile ~/lab/pull-secret.txt` |
| Provider **telmate/proxmox 2.9** sur PVE 9 | **3.0.2-rc10** |
| `disk { type = "scsi" }` (provider 3) | `type = "disk"`, slot `scsi0` / `scsi1` |
| `cores = N` (provider 3) | bloc `cpu { cores = N }` |
| Rôle PVE avec **VM.Monitor** | Administrator / token sans separation |

## Fichiers à versionner

| Fichier | Commit git ? |
|---------|----------------|
| `terraform/proxmox/.terraform.lock.hcl` | **Oui** (provider épinglé) |
| `terraform/proxmox/terraform.tfvars` | **Non** (secrets) |
| `versions.env` | **Non** |
| `~/lab/` sur bastion | Hors dépôt |

## Vérifications rapides

```bash
# Mac — Terraform registry
cd terraform/proxmox && terraform validate

# Bastion — binaire mirror
oc-mirror version 2>/dev/null || oc-mirror --v2 --help | head -1

# Proxmox API (secret dans terraform.tfvars, guillemets simples)
# curl -sk -H 'Authorization: PVEAPIToken=root@pam!terraform=SECRET' \
#   https://192.168.1.147:8006/api2/json/version
```

## Hors scope / connu

- **Ansible** : squelette ; pas de déploiement complet dnsmasq/registry TLS automatisé.
- **RC 5** (`ocp5-rc`) : configs exemple ; pas la piste active du lab aujourd’hui.
- Titres historiques « oc mirror » dans CHANGELOG ancien : le comportement documenté est **oc-mirror**.

## Liens

- [mirror/README.md](../mirror/README.md) · [terraform/README.md](../terraform/README.md) · [docs/iac.md](iac.md) · [docs/lab-power-cycle.md](lab-power-cycle.md)

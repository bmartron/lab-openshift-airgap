# Terraform — OCP 5 Assisted `ocp-bma` (stack **isolé**)

**État Terraform séparé** de [`../lab-airgap/`](../lab-airgap/) (dns, registry, bastion air-gap 4.22).

| Répertoire | Gère | State |
|------------|------|--------|
| `terraform/lab-airgap/` | dns, registry, bastion | `lab-airgap/terraform.tfstate` |
| **`terraform/assisted-ocp-bma/`** | `ocp-bma-ai-0..2` | `assisted-ocp-bma/terraform.tfstate` |

Stockages Proxmox : disques **`nfs_vm`**, ISO **`nfs_iso:iso/...`** — [../README.md](../README.md).

## Usage (Mac)

```bash
cd terraform/assisted-ocp-bma
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Doc install : [openshift/5-rc/assisted-connected/README.md](../../openshift/5-rc/assisted-connected/README.md).

## Ressources par nœud (défaut)

| | Valeur |
|---|--------|
| vCPU | 13 (`cpu_cores`) |
| RAM | 34 GiB (`memory_mb = 34816`) |
| scsi0 | 120 Go — install (`disk_gb`) |
| scsi1 | 50 Go — optionnel (`extra_disk_gb`, `0` pour désactiver) |

`lifecycle { ignore_changes = [disk] }` : un **2e disque** sur VMs **déjà** créées ne s’ajoute pas toujours via `apply` — ajouter **scsi1 50 Go** à la main dans Proxmox, ou `terraform apply -replace='proxmox_vm_qemu.node[0]'` (destructif).

## Ancien state `lab-airgap` avec VMs ocp-bma

Si des `ocp-bma-ai-*` étaient dans le mauvais state : les retirer avec `terraform state rm` côté `lab-airgap`, ou les laisser hors Terraform après suppression manuelle.

## Lab 4.22

Ne pas mélanger avec ce stack. Suppression air-gap côté Proxmox : voir [../README.md](../README.md) § « Après suppression manuelle ».

# Lab air-gap 4.22 — arrêt volontaire

Si tu **supprimes** dns / registry / bastion / SNO dans Proxmox pour ne garder que **ocp-bma** (connecté) :

## Terraform

| Stack | Action |
|-------|--------|
| **`terraform/lab-airgap/`** | `terraform state list` puis `terraform state rm …` pour chaque VM supprimée, **ou** `rm terraform.tfstate*` et repartir à zéro quand tu reconstruiras le 4.22 |
| **`terraform/assisted-ocp-bma/`** | **Ne pas toucher** pour le lab connecté |

Ne lance **pas** `terraform destroy` dans `lab-airgap` si des VMs connectées partagent encore le state (vérifier `state list`).

## Stockages NFS (noms NUC)

| ID | Usage |
|----|--------|
| **`nfs_vm`** | Disques VM |
| **`nfs_iso`** | ISO (`/mnt/pve/nfs_iso/template/iso/`) |

## Reconstruire le 4.22 plus tard

1. `terraform/lab-airgap` + `terraform.tfvars.registry.example`
2. Ansible `lab-infra.yml` / `registry.yml`
3. `oc-mirror` + SNO agent — [mirror/README.md](../mirror/README.md)

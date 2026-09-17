# Terraform — lab air-gap 4.22 (infra Proxmox)

**State isolé** : dns, registry, bastion sur `vmbr1` / `vmbr0`.  
**Ne pas** y déployer OCP5 Assisted — utiliser [`../assisted-ocp-bma/`](../assisted-ocp-bma/).

## Stockage

| Variable / champ | Valeur NUC |
|------------------|------------|
| `storage` (disques VM) | **`nfs_vm`** |
| ISO install registry | **`nfs_iso:iso/rhel-10....iso`** |

Copier ISO agent SNO vers : **`/mnt/pve/nfs_iso/template/iso/`** (voir [docs/ansible-ocp-install.md](../../docs/ansible-ocp-install.md)).

## Usage

```bash
cd terraform/lab-airgap
cp terraform.tfvars.registry.example terraform.tfvars
terraform init
terraform plan    # vérifier : 0 ressource hors infra air-gap
terraform apply
```

Flags usuels :

| Variable | Lab actuel |
|----------|------------|
| `create_dns` | `false` si VM déjà manuelle |
| `create_bastion` | `false` |
| `create_registry` | `true` pour (re)créer registry |

## State vs Proxmox

Si tu **supprimes** des VMs à la main : `terraform state rm proxmox_vm_qemu.registry[0]` (etc.) ou state vierge + `apply` — voir [../README.md](../README.md).

## Suite

[registry/README.md](../../registry/README.md) · [ansible/playbooks/lab-infra.yml](../../ansible/playbooks/lab-infra.yml)

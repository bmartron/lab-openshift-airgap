# Terraform — lab air-gap OpenShift 4.22

**Uniquement** infra Proxmox isolée (`vmbr1`) : **dns**, **registry**, **bastion**, **SNO**.  
OpenShift 5 connecté (`ocp-bma`) → [`../assisted-ocp-bma/`](../assisted-ocp-bma/) — **autre state**.

## Fichiers

| Fichier | Rôle |
|---------|------|
| `vm-dns.tf` | VM `dns` — 172.16.10.11 |
| `vm-registry.tf` | VM `registry` — scsi0 + scsi1 |
| `vm-bastion.tf` | VM `bastion` — vmbr0 + vmbr1 |
| `vm-sno.tf` | VM `ocp-sno` — ISO agent, disque install, disque LVMS optionnel |
| `variables.tf` | `create_*`, stockages **`nfs_vm`** / ISO **`nfs_iso:iso/...`** |
| `locals.tf` | OVMF + q35, tailles dns/registry/bastion |

## Exemples tfvars

| Fichier | Usage |
|---------|--------|
| [terraform.tfvars.airgap.example](terraform.tfvars.airgap.example) | Lab complet (4 VMs) |
| [terraform.tfvars.registry.example](terraform.tfvars.registry.example) | Registry seule (réinstall) |
| [terraform.tfvars.example](terraform.tfvars.example) | dns + bastion + registry (SNO hors Terraform) |

**`terraform.tfvars`** (local) ne doit **jamais** contenir `create_ocp5_*` / `ocp5_assisted_*` — ces clés n’existent plus ici. OCP5 → copier [../assisted-ocp-bma/terraform.tfvars.example](../assisted-ocp-bma/terraform.tfvars.example) vers `../assisted-ocp-bma/terraform.tfvars`.

```bash
cd terraform/lab-airgap
cp terraform.tfvars.airgap.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

## Nettoyer les restes OCP5 dans ce dossier

Ce répertoire ne doit **pas** contenir :

- `ocp-bma.auto.tfvars` / `*assisted*` / variables `create_ocp5_*`

Supprimer localement :

```bash
rm -f ocp-bma.auto.tfvars terraform.tfvars.ocp*
```

Puis `terraform state list` — retirer toute ressource `ocp-bma` orpheline :

```bash
terraform state rm 'proxmox_vm_qemu.ocp5_assisted[0]'  # adapter si présent
```

## Stockages Proxmox

| ID | Usage |
|----|--------|
| **`nfs_vm`** | `storage = "nfs_vm"` |
| **`nfs_iso`** | `nfs_iso:iso/agent.x86_64.iso`, ISO RHEL registry, discovery **non** (discovery = stack assisted) |

## Après apply

| VM | Suite |
|----|--------|
| dns / registry / bastion | [ansible/playbooks/lab-infra.yml](../../ansible/playbooks/lab-infra.yml) |
| SNO | ISO agent, MAC dans `agent-config` — [proxmox/sno-vm.md](../../proxmox/sno-vm.md), [docs/ansible-ocp-install.md](../../docs/ansible-ocp-install.md) |

## State

`terraform.tfstate` local (gitignoré). VMs supprimées à la main → [docs/lab-airgap-teardown.md](../../docs/lab-airgap-teardown.md).

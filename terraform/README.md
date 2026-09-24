# Terraform — Proxmox stacks (separate labs)

Two **directories = two states** — never mix connected OCP5 with air-gap 4.22 infra.

| Stack | Directory | Resources | Typical network |
|-------|-----------|-----------|-----------------|
| **Lab air-gap 4.22** | [`lab-airgap/`](lab-airgap/) | dns, registry, bastion | `vmbr1` + `vmbr0` (bastion) |
| **OCP5 Assisted connected** | [`assisted-ocp-bma/`](assisted-ocp-bma/) | `ocp-bma-ai-0..2` | `vmbr0` (LAN + Internet) |

SNO VM (`create_sno`): [lab-airgap/](lab-airgap/) (`vm-sno.tf`) — boot/install: [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).

## Proxmox NFS storage (NUC)

| Proxmox ID | Role | Mount on `pve` | Terraform usage |
|------------|------|----------------|-----------------|
| **`local-lvm`** | **registry + SNO** disks + template `rhel10-tpl` | Local LVM thin | `storage_perf` |
| **`nfs_vm`** | **dns + bastion** disks + template `rhel10-nfs` | `/mnt/pve/nfs_vm/` | `storage_infra` |
| **`nfs_iso`** | ISO images | `/mnt/pve/nfs_iso/template/iso/` | `nfs_iso:iso/file.iso` |

Proxmox format: **`nfs_iso:iso/name.iso`** (ISO); disks via `storage_infra` / `storage_perf`.  
Cloud-init: **same datastore as the OS** (no third variable).  
RHEL templates: [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md) (**two** templates — EFI + NFS/SSD mix).

Check on **pve** (`root@192.168.1.147`):

```bash
pvesm status
pvesm path nfs_iso:iso
```

Variables: [versions.env.example](../versions.env.example) (`PROXMOX_STORAGE_INFRA`, `PROXMOX_STORAGE_PERF`, `PROXMOX_STORAGE_ISO`).

## Lab air-gap

```bash
cd terraform/lab-airgap
cp terraform.tfvars.airgap.example terraform.tfvars   # or .registry.example
terraform init && terraform plan && terraform apply
```

VM files: `vm-dns.tf`, `vm-registry.tf`, `vm-bastion.tf`, `vm-sno.tf`.  
Docs: [lab-airgap/README.md](lab-airgap/README.md) · [docs/iac.md](../docs/iac.md).

## Connected OCP5 (ocp-bma.home.arpa)

```bash
cd terraform/assisted-ocp-bma
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

Docs: [assisted-ocp-bma/README.md](assisted-ocp-bma/README.md) · [openshift/5-rc/assisted-connected/README.md](../openshift/5-rc/assisted-connected/README.md).

## Pause / teardown air-gap (keep Assisted connected)

If you delete dns / registry / bastion / SNO in Proxmox and only keep **ocp-bma**:

| Stack | Action |
|-------|--------|
| **`terraform/lab-airgap/`** | `terraform state list` then `terraform state rm …` for each deleted VM, **or** remove `terraform.tfstate*` and start clean when you rebuild 4.22 |
| **`terraform/assisted-ocp-bma/`** | **Do not touch** for the connected lab |

Do **not** run `terraform destroy` in `lab-airgap` if connected VMs still share that state (check `state list` first).

### After manual VM deletion

1. Delete VMs in Proxmox (UI).
2. **`cd terraform/lab-airgap`** → `terraform state list` → `terraform state rm <resource>` per deleted VM, **or** delete `terraform.tfstate` and start from an empty state (then targeted `apply`).
3. Leave `assisted-ocp-bma/terraform.tfstate` alone for the connected lab.

### Rebuild air-gap later

Prefer the full path in [docs/iac.md](../docs/iac.md): RHEL templates → `terraform apply` → Ansible `lab-infra.yml` / `registry.yml` → `oc-mirror` → agent ISO.

Provider **telmate/proxmox 3.0.2-rc10** (PVE 9) — lock file in each stack.

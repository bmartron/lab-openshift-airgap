# Terraform — Proxmox lab air-gap

One stack, one state: **[`lab-airgap/`](lab-airgap/)** — dns, registry, bastion, optional SNO on `vmbr1`.

SNO boot/install: [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).  
Full rebuild: [docs/iac.md](../docs/iac.md).

## Proxmox NFS storage (NUC)

| Proxmox ID | Role | Mount on `pve` | Terraform usage |
|------------|------|----------------|-----------------|
| **`local-lvm`** | **registry + SNO** disks + template `rhel10-tpl` | Local LVM thin | `storage_perf` |
| **`nfs_vm`** | **dns + bastion** disks + template `rhel10-nfs` | `/mnt/pve/nfs_vm/` | `storage_infra` |
| **`nfs_iso`** | ISO images | `/mnt/pve/nfs_iso/template/iso/` | `nfs_iso:iso/file.iso` |

Proxmox format: **`nfs_iso:iso/name.iso`** (ISO); disks via `storage_infra` / `storage_perf`.  
Cloud-init: **same datastore as the OS**.  
RHEL templates: [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md) (**two** templates — EFI + NFS/SSD mix).

Check on **pve** (`root@192.168.1.147`):

```bash
pvesm status
pvesm path nfs_iso:iso
```

Variables: [versions.env.example](../versions.env.example) (`PROXMOX_STORAGE_INFRA`, `PROXMOX_STORAGE_PERF`, `PROXMOX_STORAGE_ISO`).

## Apply (Mac)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-airgap
cp terraform.tfvars.airgap.example terraform.tfvars
# Edit: Proxmox token + ssh_public_key_file = "/Users/bmartron/.ssh/id_ed25519.pub"
terraform init && terraform plan && terraform apply
```

Details: [lab-airgap/README.md](lab-airgap/README.md).

## After destroy/apply (Mac)

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh-keygen -R 172.16.10.100
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

Then Ansible `lab-infra.yml` — [docs/iac.md](../docs/iac.md).

## Teardown

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-airgap
terraform destroy -auto-approve
```

Or delete VMs in Proxmox UI and clean state: `terraform state list` / `terraform state rm …` / remove `terraform.tfstate*`.

Provider **telmate/proxmox 3.0.2-rc10** (PVE 9) — lock file in `lab-airgap/`.

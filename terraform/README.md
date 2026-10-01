# Terraform — Proxmox lab air-gap

Two stacks, **two states**:

| Stack | Path | VMs | Lifecycle |
|-------|------|-----|-----------|
| **Infra** | [`lab-infra/`](lab-infra/) | dns, registry, bastion | Rare rebuild |
| **OCP** | [`lab-ocp/`](lab-ocp/) | SNO **or** compact 3-node | Frequent destroy/apply |

Apply order: **infra first**, then **ocp**. Destroy OCP alone without touching bastion/DNS/registry.

Infra: **linked clones** from RHEL templates (fast). OCP: empty disks + agent ISO.

SNO / agent boot: [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).  
Full rebuild: [docs/iac.md](../docs/iac.md).

Legacy monorepo `lab-airgap/` is **deprecated** — see [lab-airgap/README.md](lab-airgap/README.md) for state migration.

## Proxmox NFS storage (NUC)

| Proxmox ID | Role | Mount on `pve` | Terraform usage |
|------------|------|----------------|-----------------|
| **`local-lvm`** | **registry + OCP** disks + template `rhel10-tpl` | Local LVM thin | `storage_perf` |
| **`nfs_vm`** | **dns + bastion** disks + template `rhel10-nfs` | `/mnt/pve/nfs_vm/` | `storage_infra` (`lab-infra`) |
| **`nfs_iso`** | ISO images | `/mnt/pve/nfs_iso/template/iso/` | `nfs_iso:iso/file.iso` |

Proxmox format: **`nfs_iso:iso/name.iso`** (ISO); disks via `storage_infra` / `storage_perf`.  
Cloud-init: **same datastore as the OS**.  
RHEL templates: [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md) (**two** templates — EFI + NFS/SSD mix).  

Terraform provider: **bpg/proxmox** — infra uses **linked clones** by default (`full_clone = false`).

Check on **pve** (`root@192.168.1.147`):

```bash
pvesm status
pvesm path nfs_iso:iso
```

Variables: [versions.env.example](../versions.env.example) (`PROXMOX_STORAGE_INFRA`, `PROXMOX_STORAGE_PERF`, `PROXMOX_STORAGE_ISO`).

## Apply (Mac)

### Infra

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-infra
cp terraform.tfvars.example terraform.tfvars
# Edit: Proxmox token + ssh_public_key_file = "/Users/bmartron/.ssh/id_ed25519.pub"
# Enable Snippets on Proxmox storage "local"; ssh-add Mac key for snippet upload
terraform init -upgrade && terraform plan && terraform apply
```

Details: [lab-infra/README.md](lab-infra/README.md).

### OCP (SNO example)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
cp terraform.tfvars.sno.example terraform.tfvars
# Edit: Proxmox token; or use terraform.tfvars.compact3.example for 3 nodes
terraform init && terraform plan && terraform apply
```

Details: [lab-ocp/README.md](lab-ocp/README.md).

## After destroy/apply (Mac)

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh-keygen -R 172.16.10.100
# compact3:
# ssh-keygen -R 172.16.10.101
# ssh-keygen -R 172.16.10.102
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

Then Ansible `lab-infra.yml` — [docs/iac.md](../docs/iac.md).

## Teardown

```bash
# OCP nodes only
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform destroy -auto-approve

# Infra (rare)
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-infra
terraform destroy -auto-approve
```

Or delete VMs in Proxmox UI and clean state: `terraform state list` / `terraform state rm …` / remove `terraform.tfstate*`.

Provider **[bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox)** — lock files in `lab-infra/` and `lab-ocp/`.  
Infra VMs default to **linked clone** (`full_clone = false`) for fast rebuilds.

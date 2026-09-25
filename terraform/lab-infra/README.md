# Terraform — lab infra (dns, bastion, registry)

Isolated Proxmox lab (`vmbr1`): **dns**, **bastion**, **registry** only.

OpenShift node VMs live in **[../lab-ocp/](../lab-ocp/)** (separate state).

## Files

| File | Role |
|------|------|
| `vm-dns.tf` | VM `dns` — 172.16.10.11 — clone `rhel10-nfs` |
| `vm-bastion.tf` | VM `bastion` — vmbr0 + vmbr1 — clone `rhel10-nfs` |
| `vm-registry.tf` | VM `registry` — clone `rhel10-tpl`: virtio0 + virtio1 |
| `variables.tf` | `create_*`, templates, storage |
| `locals.tf` | OVMF + q35, sizes |

**RHEL disks (clone):** OS on **`virtio0`** (`/dev/vda`). Registry data: **`virtio1`** (`/dev/vdb`).  
DVD repo: **`rhel_dvd_iso`** → **`ide2`** — [ansible/README.md](../../ansible/README.md) § RHEL DVD.

**Templates:** [proxmox/rhel-cloudinit-template.md](../../proxmox/rhel-cloudinit-template.md).

## Storage

| Variable | Datastore | Usage |
|----------|-----------|--------|
| **`storage_infra`** | **`nfs_vm`** | dns, bastion |
| **`storage_perf`** | **`local-lvm`** | registry |
| ISO | **`nfs_iso:iso/...`** | CD-ROM |

## Examples

| File | Usage |
|------|--------|
| [terraform.tfvars.example](terraform.tfvars.example) | dns + bastion + registry |
| [terraform.tfvars.registry.example](terraform.tfvars.registry.example) | Registry only |

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-infra
cp terraform.tfvars.example terraform.tfvars
# Proxmox token + ssh_public_key_file = "/Users/bmartron/.ssh/id_ed25519.pub"
terraform init && terraform plan && terraform apply
```

### After every destroy/apply (Mac)

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

Then Ansible: [docs/iac.md](../../docs/iac.md).

## After apply

| VM | Next |
|----|------|
| dns / registry / bastion | [ansible/playbooks/lab-infra.yml](../../ansible/playbooks/lab-infra.yml) |
| registry data | `registry_data_device: /dev/vdb` |
| OCP nodes | [../lab-ocp/](../lab-ocp/) |

## Migrating from `lab-airgap`

If you already have a `lab-airgap` state with infra VMs:

```bash
# Mac
cp terraform/lab-airgap/terraform.tfstate terraform/lab-infra/terraform.tfstate
cd terraform/lab-infra
terraform init
# If SNO was in the old state (VM stays on Proxmox):
terraform state rm 'proxmox_vm_qemu.sno[0]'
terraform plan   # expect no destroy of dns/bastion/registry
```

Overview: [terraform/README.md](../README.md).

## State

`terraform.tfstate` is local (gitignored). Independent from `lab-ocp`.

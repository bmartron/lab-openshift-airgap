# Terraform — lab infra (dns, bastion, registry)

Isolated Proxmox lab (`vmbr1`): **dns**, **bastion**, **registry** only.

Provider: **[bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox)** (not Telmate).  
Default clone mode: **linked** (`full_clone = false`) — fast destroy/apply.

OpenShift node VMs: **[../lab-ocp/](../lab-ocp/)** (separate state).

## Files

| File | Role |
|------|------|
| `vm-dns.tf` | VM `dns` — linked clone `rhel10-nfs` (VMID 101) |
| `vm-bastion.tf` | VM `bastion` — dual NIC + custom user-data |
| `vm-registry.tf` | VM `registry` — linked clone `rhel10-tpl` (VMID 100) + virtio1 |
| `cloud-init-bastion.tf` | Snippet `manage_etc_hosts: false` |
| `cloud-init/bastion-user.yaml.tftpl` | Bastion cloud-init user-data |
| `variables.tf` / `locals.tf` | IDs, storage, clone mode |

**RHEL disks (clone):** OS on **`virtio0`**. Registry data: **`virtio1`**.  
DVD repo: **`rhel_dvd_iso`** → **`ide0`** (cloud-init keeps **`ide2`**; q35 has no `ide3`).

**Templates:** [proxmox/rhel-cloudinit-template.md](../../proxmox/rhel-cloudinit-template.md).

### Linked clone

| | |
|---|---|
| Default | `full_clone = false` |
| Requirement | Template and VM on the **same** datastore (`nfs_vm` / `local-lvm`) |
| Trade-off | Fast + small; do not delete/move the template while clones exist |

### Bastion `/etc/hosts`

Proxmox default user-data sets `manage_etc_hosts: true` and wipes `/etc/hosts` on reboot.  
This stack uploads a snippet with **`manage_etc_hosts: false`** via `proxmox_virtual_environment_file` + `user_data_file_id`.

Prerequisite: storage **`local`** (or `snippets_datastore`) has **Snippets** enabled.  
SSH agent on the Mac must reach `root@` Proxmox (snippet upload).

## Storage

| Variable | Datastore | Usage |
|----------|-----------|--------|
| **`storage_infra`** | **`nfs_vm`** | dns, bastion |
| **`storage_perf`** | **`local-lvm`** | registry |
| **`snippets_datastore`** | **`local`** | bastion user-data |
| ISO | **`nfs_iso:iso/...`** | CD-ROM |

## Examples

| File | Usage |
|------|--------|
| [terraform.tfvars.example](terraform.tfvars.example) | dns + bastion + registry |
| [terraform.tfvars.registry.example](terraform.tfvars.registry.example) | Registry only |

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-infra
cp terraform.tfvars.example terraform.tfvars
# Proxmox token + ssh_public_key_file
# Enable Snippets on datastore "local"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519   # after Mac reboot
terraform init -upgrade
terraform plan
terraform apply
```

### Migration from Telmate

State is **not** compatible. Destroy old Telmate-managed VMs (or remove from state), then `terraform init -upgrade` and `apply` with BPG. Linked clones recreate infra in minutes.

### After every destroy/apply (Mac)

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

Then Ansible: `ansible-playbook playbooks/lab-infra.yml --ask-become-pass`.

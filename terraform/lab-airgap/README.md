# Terraform — lab air-gap OpenShift 4.22

Proxmox isolated lab (`vmbr1`): **dns**, **registry**, **bastion**, **SNO**.

## Files

| File | Role |
|------|------|
| `vm-dns.tf` | VM `dns` — 172.16.10.11 — clone `rhel10-nfs` |
| `vm-bastion.tf` | VM `bastion` — vmbr0 + vmbr1 — clone `rhel10-nfs` |
| `vm-registry.tf` | VM `registry` — clone `rhel10-tpl`: virtio0 + virtio1 |
| `vm-sno.tf` | VM `ocp-sno` — VirtIO disks, fixed `sno_mac` |
| `variables.tf` | `create_*`, templates, storage |
| `locals.tf` | OVMF + q35, sizes |

**RHEL disks (clone):** OS on **`virtio0`** (`/dev/vda`). Registry data: **`virtio1`** (`/dev/vdb`).  
DVD repo: **`rhel_dvd_iso`** → **`ide2`** — [ansible/README.md](../../ansible/README.md) § RHEL DVD.  
SNO: prefer **`/dev/disk/by-path/pci-…`** for install disk; optional LVMS on **virtio1**.

**Templates:** [proxmox/rhel-cloudinit-template.md](../../proxmox/rhel-cloudinit-template.md).

## Storage

| Variable | Datastore | Usage |
|----------|-----------|--------|
| **`storage_infra`** | **`nfs_vm`** | dns, bastion |
| **`storage_perf`** | **`local-lvm`** | registry, SNO |
| ISO | **`nfs_iso:iso/...`** | CD-ROM |

## Examples

| File | Usage |
|------|--------|
| [terraform.tfvars.airgap.example](terraform.tfvars.airgap.example) | Full lab |
| [terraform.tfvars.registry.example](terraform.tfvars.registry.example) | Registry only |
| [terraform.tfvars.example](terraform.tfvars.example) | dns + bastion + registry |

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-airgap
cp terraform.tfvars.airgap.example terraform.tfvars
# Proxmox token + ssh_public_key_file = "/Users/bmartron/.ssh/id_ed25519.pub"
terraform init && terraform plan && terraform apply
```

### After every destroy/apply (Mac)

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh-keygen -R 172.16.10.100
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

Full sequence: [docs/iac.md](../../docs/iac.md).

## SNO VM

In `terraform.tfvars`: `create_sno = true`, `sno_mac = "BC:24:11:E1:8F:82"` (match Ansible `ocp_sno_mac`).  
Optional: `sno_agent_iso = "nfs_iso:iso/agent.x86_64.iso"`.

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-airgap
terraform apply -target='proxmox_vm_qemu.sno[0]' -auto-approve
# recreate:
terraform apply -replace='proxmox_vm_qemu.sno[0]' -auto-approve
```

Boot: [openshift/4.22-ga/README.md](../../openshift/4.22-ga/README.md).

## After apply

| VM | Next |
|----|------|
| dns / registry / bastion | [ansible/playbooks/lab-infra.yml](../../ansible/playbooks/lab-infra.yml) |
| registry data | `registry_data_device: /dev/vdb` |
| SNO | [openshift/4.22-ga/README.md](../../openshift/4.22-ga/README.md) |

## State

`terraform.tfstate` is local (gitignored). Overview: [terraform/README.md](../README.md).

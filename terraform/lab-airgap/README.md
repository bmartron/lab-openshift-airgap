# Terraform — lab air-gap OpenShift 4.22

**Uniquement** infra Proxmox isolée (`vmbr1`) : **dns**, **registry**, **bastion**, **SNO**.  
OpenShift 5 connecté (`ocp-bma`) → [`../assisted-ocp-bma/`](../assisted-ocp-bma/) — **autre state**.

## Fichiers

| Fichier | Rôle |
|---------|------|
| `vm-dns.tf` | VM `dns` — 172.16.10.11 — clone `rhel10-nfs` |
| `vm-bastion.tf` | VM `bastion` — vmbr0 + vmbr1 — clone `rhel10-nfs` |
| `vm-registry.tf` | VM `registry` — clone `rhel10-tpl` : virtio0 + virtio1 ; ou ISO : scsi0 + scsi1 |
| `vm-sno.tf` | VM `ocp-sno` — VirtIO disks (`/dev/vda` + optional `/dev/vdb`), fixed `sno_mac` |
| `variables.tf` | `create_*`, `rhel_template` / `rhel_template_infra`, stockages |
| `locals.tf` | OVMF + q35, tailles |

**Disques RHEL (clone)** : OS en **`virtio0`** (`/dev/vda`) — aligné sur le template. Registry données : **`virtio1`** (`/dev/vdb`).  
DVD repo : **`rhel_dvd_iso`** → **`ide2`** (souvent `/dev/sr1` ; `/dev/sr0` = cloud-init) — [ansible/README.md](../../ansible/README.md) § RHEL DVD.
SNO / Assisted: prefer **`/dev/disk/by-path/pci-…`** for install disk (VirtIO `virtio0`); LVMS on **virtio1**.

**Templates** : [proxmox/rhel-cloudinit-template.md](../../proxmox/rhel-cloudinit-template.md) — **deux** templates (EFI Telmate + cross-storage).

## Stockage

| Variable | Datastore | Usage |
|----------|-----------|--------|
| **`storage_infra`** | **`nfs_vm`** | OS + EFI + cloud-init **dns**, **bastion** (`rhel10-nfs`) |
| **`storage_perf`** | **`local-lvm`** | OS + EFI + cloud-init + données **registry** / **SNO** (`rhel10-tpl`) |
| ISO | **`nfs_iso:iso/...`** | CD-ROM |

## Exemples tfvars

| Fichier | Usage |
|---------|--------|
| [terraform.tfvars.airgap.example](terraform.tfvars.airgap.example) | Lab complet |
| [terraform.tfvars.registry.example](terraform.tfvars.registry.example) | Registry seule |
| [terraform.tfvars.example](terraform.tfvars.example) | dns + bastion + registry |

```bash
cd terraform/lab-airgap
cp terraform.tfvars.airgap.example terraform.tfvars
# renseigner token + vérifier rhel10-tpl / rhel10-nfs sur Proxmox
terraform init && terraform plan && terraform apply
```

## SNO VM (create / retry)

In `terraform.tfvars`: `create_sno = true`, `sno_mac = "BC:24:11:E1:8F:82"` (must match Ansible `ocp_sno_mac`). Agent ISO on NFS if used: `sno_agent_iso = "nfs_iso:iso/agent.x86_64.iso"`.

**Mac** — create / apply SNO only:

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-airgap
terraform apply -target='proxmox_vm_qemu.sno[0]' -auto-approve
```

**Mac** — recreate (install retry):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-airgap
terraform apply -replace='proxmox_vm_qemu.sno[0]' -auto-approve
```

Then boot/install: [openshift/4.22-ga/README.md](../../openshift/4.22-ga/README.md).

## Après apply

| VM | Suite |
|----|--------|
| dns / registry / bastion | [ansible/playbooks/lab-infra.yml](../../ansible/playbooks/lab-infra.yml) |
| registry données | `registry_data_device: /dev/vdb` — [ansible/group_vars/all.yml.example](../../ansible/group_vars/all.yml.example) |
| SNO | commands above · [vm-sno.tf](vm-sno.tf) · [openshift/4.22-ga/README.md](../../openshift/4.22-ga/README.md) |

## State

`terraform.tfstate` local (gitignoré). Teardown / pause air-gap : [terraform/README.md](../README.md) § Pause / teardown.

# Terraform — lab air-gap OpenShift 4.22

**Uniquement** infra Proxmox isolée (`vmbr1`) : **dns**, **registry**, **bastion**, **SNO**.  
OpenShift 5 connecté (`ocp-bma`) → [`../assisted-ocp-bma/`](../assisted-ocp-bma/) — **autre state**.

## Fichiers

| Fichier | Rôle |
|---------|------|
| `vm-dns.tf` | VM `dns` — 172.16.10.11 — clone `rhel10-nfs` |
| `vm-bastion.tf` | VM `bastion` — vmbr0 + vmbr1 — clone `rhel10-nfs` |
| `vm-registry.tf` | VM `registry` — clone `rhel10-tpl` : virtio0 + virtio1 ; ou ISO : scsi0 + scsi1 |
| `vm-sno.tf` | VM `ocp-sno` — ISO agent, disques RHCOS |
| `variables.tf` | `create_*`, `rhel_template` / `rhel_template_infra`, stockages |
| `locals.tf` | OVMF + q35, tailles |

**Disques RHEL (clone)** : OS en **`virtio0`** (`/dev/vda`) — aligné sur le template. Registry données : **`virtio1`** (`/dev/vdb`).  
DVD repo : **`rhel_dvd_iso`** → **`ide2`** (souvent `/dev/sr1` ; `/dev/sr0` = cloud-init) — [rhel/dvd-repo.md](../../rhel/dvd-repo.md).  
SNO / Assisted restent en **SCSI** (`/dev/sda`).

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

## Après apply

| VM | Suite |
|----|--------|
| dns / registry / bastion | [ansible/playbooks/lab-infra.yml](../../ansible/playbooks/lab-infra.yml) |
| registry données | `registry_data_device: /dev/vdb` — [ansible/group_vars/all.yml.example](../../ansible/group_vars/all.yml.example) |
| SNO | [proxmox/sno-vm.md](../../proxmox/sno-vm.md), [docs/ansible-ocp-install.md](../../docs/ansible-ocp-install.md) |

## State

`terraform.tfstate` local (gitignoré). Teardown : [docs/lab-airgap-teardown.md](../../docs/lab-airgap-teardown.md).

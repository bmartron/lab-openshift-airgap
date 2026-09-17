# Terraform — stacks Proxmox (labs séparés)

Deux **répertoires = deux states** — ne jamais mélanger OCP5 connecté et infra air-gap 4.22.

| Stack | Répertoire | Ressources | Réseau typique |
|-------|------------|----------|----------------|
| **Lab air-gap 4.22** | [`lab-airgap/`](lab-airgap/) | dns, registry, bastion | `vmbr1` + `vmbr0` (bastion) |
| **OCP5 Assisted connecté** | [`assisted-ocp-bma/`](assisted-ocp-bma/) | `ocp-bma-ai-0..2` | `vmbr0` (LAN + Internet) |

OpenShift / Proxmox manuel (SNO agent, etc.) : hors Terraform — [proxmox/sno-vm.md](../proxmox/sno-vm.md).

## Stockages NFS Proxmox (NUC)

| ID Proxmox | Rôle | Chemin monté sur `pve` | Usage Terraform |
|------------|------|-------------------------|-----------------|
| **`nfs_vm`** | Disques VM, templates | `/mnt/pve/nfs_vm/` | `storage = "nfs_vm"` |
| **`nfs_iso`** | Images ISO | `/mnt/pve/nfs_iso/template/iso/` | `nfs_iso:iso/fichier.iso` |

Format Proxmox : **`nfs_iso:iso/nom.iso`** (ISO), **`nfs_vm`** pour `scsi0` / `efidisk`.

Vérifier sur **pve** :

```bash
pvesm status
pvesm path nfs_iso:iso
ls /mnt/pve/nfs_iso/template/iso/
```

Variables partagées : [versions.env.example](../versions.env.example) (`PROXMOX_STORAGE_VM`, `PROXMOX_STORAGE_ISO`).

## Lab air-gap

```bash
cd terraform/lab-airgap
cp terraform.tfvars.airgap.example terraform.tfvars   # ou .registry.example
terraform init && terraform plan && terraform apply
```

Fichiers VM : `vm-dns.tf`, `vm-registry.tf`, `vm-bastion.tf`, `vm-sno.tf`.  
Doc : [lab-airgap/README.md](lab-airgap/README.md).

## OCP5 connecté (ocp-bma.home.arpa)

```bash
cd terraform/assisted-ocp-bma
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

Doc : [assisted-ocp-bma/README.md](assisted-ocp-bma/README.md) · [openshift/5-rc/assisted-connected/README.md](../openshift/5-rc/assisted-connected/README.md).

## Après suppression manuelle des VMs air-gap

1. Supprimer dans Proxmox (UI).
2. **`cd terraform/lab-airgap`** → `terraform state list` → `terraform state rm <ressource>` pour chaque VM supprimée, **ou** supprimer `terraform.tfstate` et repartir sur un state vierge (puis `apply` ciblé).
3. Ne pas toucher `assisted-ocp-bma/terraform.tfstate` pour le lab connecté.

Provider **telmate/proxmox 3.0.2-rc10** (PVE 9) — lock file dans chaque stack.

# Terraform — Proxmox (lab infra)

Provisionne les VMs **dns**, **registry**, **bastion** sur Proxmox. Le SNO OpenShift reste hors Terraform (ISO agent / cycle de vie manuel) — voir [proxmox/sno-vm.md](../proxmox/sno-vm.md).

## Proxmox VE 9

- Le privilège **`VM.Monitor` n’existe plus** (provider **2.9** → erreur Terraform). Ce dépôt utilise **telmate/proxmox 3.0.2-rc10**.
- VMs avec **qemu-guest-agent** et lecture d’IP par Terraform : ajouter **`VM.GuestAgent.Audit`** au token/rôle. La VM **registry** (install ISO) a `agent = 0` → pas besoin pour ce apply.

Après mise à jour du provider : `rm -rf .terraform .terraform.lock.hcl && terraform init`.

## Prérequis

- Proxmox `192.168.1.147` (ou `versions.env`)
- Template RHEL 10 (cloud-init ou clone) sur le nœud Proxmox — **q35 + UEFI** recommandé (aligné `locals.tf`)
- Token API : Proxmox → **Datacenter** → **Permissions** → **API Tokens**

## Scope actuel du lab (registry seule)

**dns** et **bastion** existent déjà sur Proxmox (q35 + OVMF), gérées **hors Terraform** pour l’instant.

- Dans `terraform.tfvars` : `create_dns = false`, `create_bastion = false`, `create_registry = true` (voir `terraform.tfvars.registry.example`).
- `terraform state` ne doit contenir que `proxmox_vm_qemu.registry[0]` tant qu’on n’importe pas les autres VMs.
- Les blocs **dns** / **bastion** dans `vms.tf` sont prêts (même firmware que registry) ; les activer plus tard = `create_* = true` + **plan** (risque de recréation si import absent).

`terraform plan` avec ce tfvars ne touche **pas** dns ni bastion.

## Registry seule (réinstall)

Voir [docs/registry-reinstall-terraform.md](../docs/registry-reinstall-terraform.md).

```bash
cd terraform/proxmox
cp terraform.tfvars.registry.example terraform.tfvars
terraform init && terraform plan && terraform apply
```

## Tout le lab (dns + registry + bastion)

**À utiliser seulement** pour une création from scratch ou après `terraform import` des VMs existantes — sinon `plan` peut proposer de **détruire/recréer** dns/bastion.

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Registry : second disque

La VM **registry** reçoit :

- **scsi0** : disque système (~32 Go) — OS uniquement
- **scsi1** : disque données (~120 Go) — monté par Ansible sur `/opt/registry`
- **Firmware (toutes les VMs)** : `local.vm_bios` / `local.vm_machine` → OVMF + q35 + `efidisk` sur `var.storage`

Évite le piège RHEL « `/` 70 Go + `/home` 70 Go » — voir [registry/README.md](../registry/README.md).

## VMs déjà créées

Terraform peut **recréer** des VMs si les noms/IDs entrent en conflit. Pour un lab existant :

1. Commencer par **Ansible seul** ([ansible/README.md](../ansible/README.md)) sur l’inventaire actuel.
2. Ou `terraform import` (avancé) — non documenté ici.

## Secrets

- `terraform.tfvars` est **gitignoré**
- Ne pas committer de token Proxmox

## Suite

Après `apply` : [ansible/README.md](../ansible/README.md) — `playbooks/lab-infra.yml`.

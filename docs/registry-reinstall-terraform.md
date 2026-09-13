# Registry — étape 2 avec Terraform

Après **suppression** de la VM registry dans Proxmox (étape 1 manuelle).

## Prérequis

- Token API Proxmox (`root@pam!terraform` + secret)
- Nom exact du **datastore** et de l’**ISO RHEL 10** sur Proxmox (ex. `nfs-vm:iso/rhel-10....iso`)
- Terraform ≥ 1.5 sur le **Mac**

## Commandes (une fois)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/proxmox

cp terraform.tfvars.registry.example terraform.tfvars
nano terraform.tfvars   # token, storage, registry_install_iso

terraform init
terraform plan
terraform apply
```

Terraform crée **uniquement** la VM `registry` :

| Disque | Taille | Rôle |
|--------|--------|------|
| scsi0 | 32 Go | RHEL |
| scsi1 | 120 Go | données `/opt/registry` |
| ide2 | ISO | install (boot `ide2;scsi0`) |

Firmware : **OVMF (UEFI)** + **q35** + disque EFI — même réglage pour **dns**, **bastion**, **registry** (`locals.tf` / `vms.tf`).

`create_dns` et `create_bastion` restent à `false`.

## Après `apply`

1. Proxmox → VM **registry** → **Console** → installer RHEL (étape 3 du guide manuel).
2. Suite : [registry/README.md](../registry/README.md) (réseau, disque sdb, podman, TLS).
3. Bastion : nouvelle `ca.crt` + `oc-mirror`.

## Détruire / recréer

```bash
terraform destroy   # supprime la VM gérée par l’état Terraform
```

Ne pas supprimer à la main dans Proxmox sans `terraform state rm` si tu veux garder l’état cohérent.

## Suite globale

[registry/README.md](../registry/README.md) · [docs/iac.md](iac.md)

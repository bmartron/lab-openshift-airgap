# Deprecated: `lab-airgap`

This monorepo stack is **replaced** by two roots (two Terraform states):

| Stack | Path | Role |
|-------|------|------|
| Infra | [../lab-infra/](../lab-infra/) | dns, bastion, registry |
| OCP | [../lab-ocp/](../lab-ocp/) | SNO or compact3 |

See [../README.md](../README.md).

## Migrate existing state (once)

Your previous `terraform.tfstate` under this directory managed infra only when `create_sno = false`.

```bash
# Mac — if not already copied
cp terraform/lab-airgap/terraform.tfstate terraform/lab-infra/terraform.tfstate
cd terraform/lab-infra
cp terraform.tfvars.example terraform.tfvars   # or reuse stripped tfvars
# edit token + ssh_public_key_file
terraform init
terraform plan   # expect no destroy of dns/bastion/registry

# OCP (new empty state until you apply or import)
cd ../lab-ocp
cp terraform.tfvars.sno.example terraform.tfvars
terraform init
```

If the old state still listed SNO:

```bash
cd terraform/lab-infra
terraform state rm 'proxmox_vm_qemu.sno[0]'   # VM stays on Proxmox
```

After a clean `plan` on `lab-infra`, you may delete leftover files here (`terraform.tfstate*`, `terraform.tfvars`, `.terraform/`).

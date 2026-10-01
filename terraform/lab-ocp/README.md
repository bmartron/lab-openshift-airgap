# Terraform — OpenShift lab VMs (SNO or compact 3-node)

RHCOS / agent-based nodes on `vmbr1`. **Separate state** from infra ([../lab-infra/](../lab-infra/)).

Provider: **bpg/proxmox** (same as lab-infra). No RHEL linked clone — empty disks + agent ISO.

## Topology

| `ocp_topology` | VMs | IPs | Default MAC (node0) |
|----------------|-----|-----|---------------------|
| `sno` | `ocp-sno` | `172.16.10.100` | `BC:24:11:E1:8F:82` |
| `compact3` | `ocp-master-0..2` | `.100` / `.101` / `.102` | node0 same; `.83` / `.84` for 1/2 |

Sizing (NUC 64 GiB):

- **sno**: 8 cores / 24 GiB (override with `sno_*`)
- **compact3**: 8 cores / 16 GiB each

Optional LVMS disk: `lvms_disk_gb` (default 100; `0` to disable).

## Files

| File | Role |
|------|------|
| `vm-nodes.tf` | `proxmox_virtual_environment_vm.node` via `for_each` |
| `locals.tf` | Node map for `sno` or `compact3` |
| `variables.tf` | Topology, disks, ISO, sizing |

No cloud-init — attach agent ISO (`agent_iso`) or boot from Proxmox UI.

**Install disk hint:** prefer `/dev/disk/by-path/pci-…` in Ansible — [docs/ansible-ocp-install.md](../../docs/ansible-ocp-install.md).

## Examples

| File | Usage |
|------|--------|
| [terraform.tfvars.sno.example](terraform.tfvars.sno.example) | Single-node OpenShift |
| [terraform.tfvars.compact3.example](terraform.tfvars.compact3.example) | Three control-plane nodes |

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
cp terraform.tfvars.sno.example terraform.tfvars
# Proxmox token
terraform init -upgrade && terraform plan && terraform apply
```

### Rebuild OCP only (infra untouched)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Recreate one node

```bash
# sno
terraform apply -replace='proxmox_virtual_environment_vm.node["sno"]' -auto-approve
# compact3 master-0
terraform apply -replace='proxmox_virtual_environment_vm.node["0"]' -auto-approve
```

After destroy/apply (Mac):

```bash
ssh-keygen -R 172.16.10.100
# compact3 also:
# ssh-keygen -R 172.16.10.101
# ssh-keygen -R 172.16.10.102
```

SSH to nodes: from bastion only — [docs/sno-ssh-convention.md](../../docs/sno-ssh-convention.md).

Overview: [terraform/README.md](../README.md).

# Terraform — OpenShift lab VMs (SNO or compact 3-node)

RHCOS / agent-based nodes on `vmbr1`. **Separate state** from infra ([../lab-infra/](../lab-infra/)).

## Topology

| `ocp_topology` | VMs | IPs | Default MAC (node0) |
|----------------|-----|-----|---------------------|
| `sno` | `ocp-sno` | `172.16.10.100` | `BC:24:11:E1:8F:82` |
| `compact3` | `ocp-master-0..2` | `.100` / `.101` / `.102` | node0 same; `.83` / `.84` for 1/2 |

Sizing (NUC 64 GiB):

- **sno**: 8 cores / 24 GiB (override with `sno_*`)
- **compact3**: 4 cores / 16 GiB each

Optional LVMS disk: `lvms_disk_gb` (default 100; `0` to disable).

## Files

| File | Role |
|------|------|
| `vm-nodes.tf` | `proxmox_vm_qemu.node` via `for_each` on active topology |
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
terraform init && terraform plan && terraform apply
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
terraform apply -replace='proxmox_vm_qemu.node["sno"]' -auto-approve
# compact3 master-0
terraform apply -replace='proxmox_vm_qemu.node["0"]' -auto-approve
```

After destroy/apply (Mac):

```bash
ssh-keygen -R 172.16.10.100
# compact3 also:
# ssh-keygen -R 172.16.10.101
# ssh-keygen -R 172.16.10.102
```

SSH to nodes: from bastion only — [docs/sno-ssh-convention.md](../../docs/sno-ssh-convention.md).

## compact3 note

Terraform creates the three VMs. Multi-host `agent-config`, dnsmasq, and VIP are **not** automated yet (Ansible follow-up).

## Import existing SNO from old `lab-airgap`

If the SNO VM already exists on Proxmox and was removed from the infra state:

```bash
cd terraform/lab-ocp
cp terraform.tfvars.sno.example terraform.tfvars
# edit token; set ocp_topology = "sno"
terraform init
# Import: Proxmox node/VMID — adjust VMID from `qm list` on pve
# terraform import 'proxmox_vm_qemu.node["sno"]' pve/qemu/<VMID>
```

Or leave unmanaged until the next destroy/apply cycle.

Overview: [terraform/README.md](../README.md).

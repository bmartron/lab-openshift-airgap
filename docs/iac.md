# Infrastructure as Code (Terraform + Ansible)

**Default path** for rebuilding the lab.

| Tool | Scope |
|------|--------|
| [Terraform](../terraform/README.md) | Proxmox VMs — [`lab-infra/`](../terraform/lab-infra/) + [`lab-ocp/`](../terraform/lab-ocp/) |
| [Ansible](../ansible/README.md) | OS config: DVD, NTP, dnsmasq, registry, bastion, install-config |

OpenShift images: [mirror/](../mirror/README.md) (`oc-mirror` on bastion — **after** install configs / agent ISO).  
Install configs + agent ISO: [ansible-ocp-install.md](ansible-ocp-install.md) · boot SNO: [openshift/4.22-ga/](../openshift/4.22-ga/README.md).

## Full air-gap rebuild

**Before Terraform** — in `terraform/lab-infra/terraform.tfvars`:

```hcl
ssh_user = "bernard"
ssh_public_key_file = "/Users/bmartron/.ssh/id_ed25519.pub"
```

1. RHEL templates — [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md)
2. **Mac (once):** `podman save` → `registry:2` tar; set `registry_image_tar` — [ansible/README.md](../ansible/README.md)
3. **Mac** — wipe + recreate **infra** VMs:

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-infra
terraform destroy -auto-approve
terraform apply -auto-approve
```

4. **Mac** — recreate **OCP** VMs (SNO example):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
cp terraform.tfvars.sno.example terraform.tfvars
# edit token; ocp_topology = "sno"
terraform destroy -auto-approve   # safe if empty state
terraform apply -auto-approve
```

5. **Mac** — clear stale SSH host keys, verify bastion:

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh-keygen -R 172.16.10.100
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

6. **Mac** — OS / services (`lab-ssh` + dns + registry + bastion):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/lab-infra.yml --ask-become-pass
```

7. Set `ocp_agent_generate_iso` / `ocp_push_iso_to_proxmox` in `inventory/group_vars/all.yml`, then `bastion-ocp-install.yml` — [ansible-ocp-install.md](ansible-ocp-install.md)
8. On bastion: `oc-mirror` — [mirror/README.md](../mirror/README.md) (**do not boot SNO yet**)
9. `lab-startup-check.sh`, then boot SNO — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md)

SSH model: [ansible/README.md](../ansible/README.md) § SSH keys · [proxmox/access.md](../proxmox/access.md).

## Rebuild OCP only

Infra stays up:

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform destroy -auto-approve
terraform apply -auto-approve
```

Then regenerate agent ISO / boot — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).

## Re-run registry only

`ansible-playbook playbooks/lab-infra.yml --limit registry` (needs `registry_image_tar` on the Mac).

## Shared variables

Align with [versions.env.example](../versions.env.example) (`DNS_IP`, `REGISTRY_IP`, `PROXMOX_HOST`).

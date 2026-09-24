# Infrastructure as Code (Terraform + Ansible)

**This is the default path** for rebuilding the lab (not optional).

| Tool | Scope |
|------|--------|
| [Terraform](../terraform/README.md) | Proxmox VMs: air-gap stack (`lab-airgap/`) and Assisted connected (`assisted-ocp-bma/`) — **separate states** |
| [Ansible](../ansible/README.md) | OS config: DVD repos, NTP, dnsmasq, registry (Podman/TLS), bastion (network, CA, packages, OCP clients), install-config |

OpenShift images: [mirror/](../mirror/README.md) (`oc-mirror` on bastion).  
Install configs / agent ISO: [ansible-ocp-install.md](ansible-ocp-install.md) and [openshift/4.22-ga/](../openshift/4.22-ga/README.md).  
Connected Assisted 3-node (OCP 5): [openshift/5-rc/assisted-connected/README.md](../openshift/5-rc/assisted-connected/README.md).

## Recommended flows

### Full air-gap rebuild (dns + bastion + registry)

1. RHEL templates — [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md)
2. `cd terraform/lab-airgap` → `terraform apply` (`rhel_dvd_iso`, `bastion_admin_gateway`, SSH key file)
3. `cd ansible` → `ansible-playbook playbooks/lab-infra.yml`
4. `ansible-playbook playbooks/bastion-ocp-install.yml` (pull-secret + install YAML)
5. On bastion: `oc-mirror` — [mirror/README.md](../mirror/README.md)
6. Agent ISO + SNO — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md)

### Registry only (existing dns/bastion)

1. Token in `terraform/lab-airgap/terraform.tfvars` with `create_dns` / `create_bastion` = `false`
2. `terraform apply` → registry `virtio0` + `virtio1` (`/dev/vda` + `/dev/vdb`)
3. Ansible: `registry_data_device: /dev/vdb` → `playbooks/lab-infra.yml --limit registry` (or `registry.yml`)

### Assisted connected (OCP 5)

Use **only** [terraform/assisted-ocp-bma/](../terraform/assisted-ocp-bma/) — do not mix with `lab-airgap` state.

## Shared variables

Align with [versions.env.example](../versions.env.example) (`DNS_IP`, `REGISTRY_IP`, `PROXMOX_HOST`).

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
2. **Mac (once):** `podman pull` + `podman save` → `registry:2` tar; set `registry_image_tar` in Ansible `group_vars` — [ansible/README.md](../ansible/README.md)
3. `cd terraform/lab-airgap` → `terraform apply` (`rhel_dvd_iso`, `bastion_admin_gateway`, SSH key file)
4. `cd ansible` → `ansible-playbook playbooks/lab-infra.yml` (copies tar → `podman load` on registry; no Hub pull on the VM)
5. `ansible-playbook playbooks/bastion-ocp-install.yml` (pull-secret + install YAML)
6. On bastion: `oc-mirror` — [mirror/README.md](../mirror/README.md)
7. Agent ISO + SNO — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md)

### Re-run registry only (dns/bastion already up)

`ansible-playbook playbooks/lab-infra.yml --limit registry` (same `registry` role; needs `registry_image_tar` on the Mac). To recreate the VM: Terraform with `create_dns` / `create_bastion` = `false`, then that limit.

### Assisted connected (OCP 5)

Use **only** [terraform/assisted-ocp-bma/](../terraform/assisted-ocp-bma/) — do not mix with `lab-airgap` state.

## Shared variables

Align with [versions.env.example](../versions.env.example) (`DNS_IP`, `REGISTRY_IP`, `PROXMOX_HOST`).

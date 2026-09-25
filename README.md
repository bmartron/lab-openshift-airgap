# OpenShift Lab on Proxmox (NUC)

Personal training lab for **OpenShift 4.22 GA SNO** air-gap on **Proxmox** (NUC 15 Pro).

## How deployments work

| Layer | Tool | Role |
|-------|------|------|
| **VMs** | **[Terraform](terraform/README.md)** | Create/recreate Proxmox VMs (`lab-airgap`) |
| **OS / lab services** | **[Ansible](ansible/README.md)** | DVD repos, DNS, registry, bastion, install-config |
| **Image mirror** | Manual on bastion | `oc-mirror` |
| **Cluster install** | Agent ISO | [openshift/4.22-ga/](openshift/4.22-ga/) |

Primary entry points:

- **Terraform**: [terraform/README.md](terraform/README.md) · [terraform/lab-airgap/README.md](terraform/lab-airgap/README.md)
- **Ansible**: [ansible/README.md](ansible/README.md)
- **IaC rebuild**: [docs/iac.md](docs/iac.md)

## Platform

| Component | Detail |
|-----------|--------|
| Host | NUC 15 Pro — 64 GiB RAM |
| Hypervisor | Proxmox on **internal** 512 GiB SSD |
| VM / ISO storage | NAS NFS |
| Disk layout | Proxmox on internal 512 GiB SSD; Windows on internal 1 TiB |

## Validated track

| Track | Topology | Method | Network | Status |
|-------|----------|--------|---------|--------|
| **OpenShift 4.22 GA** | **SNO** | Agent-based air-gap (`oc-mirror` + agent ISO) | Isolated `vmbr1` | Active |

Optional / in progress:

- [ ] OpenShift Virtualization + LVMS on air-gap SNO — [docs/openshift-virt-lab.md](docs/openshift-virt-lab.md)
- [ ] Optional graphical workstation VM

## Network

| Proxmox bridge | Role | Internet |
|----------------|------|----------|
| `vmbr0` | Admin / home LAN | Yes |
| `vmbr1` | Isolated OpenShift lab | **No** |

Lab addressing (`172.16.10.0/24`): [docs/network.md](docs/network.md).

## Lab VMs

| VM | Role | Network |
|----|------|---------|
| `bastion` | `oc`, `openshift-install`, `oc-mirror` | `vmbr0` + `vmbr1` |
| `dns` | dnsmasq + NTP | `vmbr1` |
| `registry` | Mirror registry | `vmbr1` |
| `ocp-sno` | OpenShift SNO | `vmbr1` |

## Repository layout

```
.
├── docs/                  # Architecture, network, versions, procedures
├── proxmox/               # Network, SSH, RHEL cloud-init templates
├── bastion/               # Bastion notes + scripts
├── openshift/4.22-ga/     # Agent-based GA air-gap
├── dns/                   # DNS service notes
├── mirror/                # oc-mirror procedures
├── terraform/lab-airgap/  # → [terraform/README.md](terraform/README.md)
├── ansible/               # DNS, registry, bastion, OCP install
└── versions.env.example
```

## Quick start (air-gap 4.22 SNO)

1. [docs/architecture.md](docs/architecture.md)
2. [proxmox/network.md](proxmox/network.md) — `vmbr1`
3. [proxmox/rhel-cloudinit-template.md](proxmox/rhel-cloudinit-template.md)
4. **Terraform** — [terraform/README.md](terraform/README.md) ([docs/iac.md](docs/iac.md): `ssh_public_key_file` + `ssh-keygen -R`)
5. **Ansible** `lab-infra.yml` — [ansible/README.md](ansible/README.md)
6. **Ansible** `bastion-ocp-install.yml` — [docs/ansible-ocp-install.md](docs/ansible-ocp-install.md)
7. **Mirror** — [mirror/README.md](mirror/README.md)
8. Boot SNO — [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md)
9. Daily power cycle — [docs/lab-power-cycle.md](docs/lab-power-cycle.md)
10. SSH `core@` from bastion only — [docs/sno-ssh-convention.md](docs/sno-ssh-convention.md)

## Lab progress

- [x] Proxmox + NFS + `vmbr1`
- [x] Infra VMs via Terraform + Ansible
- [x] Mirror OCP 4.22.12 (`oc-mirror` v2)
- [x] SNO GA **4.22.12** air-gap
- [ ] Virt + LVMS day-2
- [ ] Optional graphical workstation VM

## Target versions

| Component | Version | Status |
|-----------|---------|--------|
| Infra VMs | **RHEL 10.2** | Done |
| OpenShift GA (SNO air-gap) | **4.22.12** | Done |
| Proxmox | **9.2.x** | Done — [docs/versions.md](docs/versions.md) |

## Notes

- Secrets (`pull-secret`, keys, kubeconfig, `terraform.tfvars`) are gitignored.
- Copy `*.example` files before use.
- Prefer **Terraform + Ansible** for repeatable rebuilds — [docs/iac.md](docs/iac.md).

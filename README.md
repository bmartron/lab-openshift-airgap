# OpenShift Lab on Proxmox (NUC)

Personal training lab for **OpenShift 4.22 GA** air-gap on **Proxmox** (NUC 15 Pro).

**Current validation:** compact **3-node** (`compact3`). **SNO** uses the same stack — only topology knobs change (`ocp_topology` + generated `install-config` / `agent-config`).

## How deployments work

| Layer | Tool | Role |
|-------|------|------|
| **VMs** | **[Terraform](terraform/README.md)** | Create/recreate Proxmox VMs (`lab-infra` + `lab-ocp`) |
| **OS / lab services** | **[Ansible](ansible/README.md)** | DVD repos, DNS, registry, bastion, install-config / agent-config |
| **Image mirror** | Manual on bastion | `oc-mirror` |
| **Cluster install** | Agent ISO | [openshift/4.22-ga/](openshift/4.22-ga/) |

Primary entry points:

- **Terraform**: [terraform/README.md](terraform/README.md) · [terraform/lab-infra/README.md](terraform/lab-infra/README.md) · [terraform/lab-ocp/README.md](terraform/lab-ocp/README.md)
- **Ansible**: [ansible/README.md](ansible/README.md)
- **IaC rebuild**: [docs/iac.md](docs/iac.md)

## SNO vs compact3 (same lab)

Same infra (bastion, DNS, registry, mirror, agent ISO flow). Switch with:

| Knob | Where | SNO | compact3 |
|------|--------|-----|----------|
| `ocp_topology` | `terraform/lab-ocp` + Ansible `group_vars` | `sno` | `compact3` |
| `install-config` | Ansible → bastion | `platform: none`, 1 master | `platform: baremetal` + API/ingress VIPs, 3 masters |
| `agent-config` | Ansible → bastion | 1 host | 3 hosts (MACs/IPs) |

Do **not** hand-edit production YAML on the bastion — regenerate via `bastion-ocp-install.yml` — [docs/ansible-ocp-install.md](docs/ansible-ocp-install.md).

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
| **OpenShift 4.22 GA** | **compact3** (3 masters) | Agent-based air-gap (`oc-mirror` + agent ISO, baremetal VIPs) | Isolated `vmbr1` | Active |
| OpenShift 4.22 GA | SNO | Same method (`platform: none`) | Isolated `vmbr1` | Supported (same configs, different topology) |

Optional / in progress:

- [ ] OpenShift Virtualization + LVMS on air-gap — [docs/openshift-virt-lab.md](docs/openshift-virt-lab.md)
- [ ] Optional graphical workstation VM

## Network

| Proxmox bridge | Role | Internet |
|----------------|------|----------|
| `vmbr0` | Admin / home LAN | Yes |
| `vmbr1` | Isolated OpenShift lab | **No** |

Lab addressing (`172.16.10.0/24`): [docs/network.md](docs/network.md).  
compact3 VIPs: API `172.16.10.50`, ingress `172.16.10.49` (DNS PTR via dnsmasq `host-record`).

## Lab VMs

| VM | Role | Network |
|----|------|---------|
| `bastion` | `oc`, `openshift-install`, `oc-mirror` | `vmbr0` + `vmbr1` |
| `dns` | dnsmasq + NTP | `vmbr1` |
| `registry` | Mirror registry | `vmbr1` |
| `ocp-master-0..2` | compact3 control plane (or `ocp-sno` if SNO) | `vmbr1` |

## Repository layout

```
.
├── docs/                  # Architecture, network, versions, procedures
├── proxmox/               # Network, SSH, RHEL cloud-init templates
├── bastion/               # Bastion notes + scripts
├── openshift/4.22-ga/     # Agent-based GA air-gap
├── dns/                   # DNS service notes
├── mirror/                # oc-mirror procedures
├── terraform/lab-infra/   # dns, bastion, registry
├── terraform/lab-ocp/     # sno or compact3
├── ansible/               # DNS, registry, bastion, OCP install
└── versions.env.example
```

## Quick start (air-gap 4.22 compact3)

1. [docs/architecture.md](docs/architecture.md)
2. [proxmox/network.md](proxmox/network.md) — `vmbr1`
3. [proxmox/rhel-cloudinit-template.md](proxmox/rhel-cloudinit-template.md)
4. **Terraform** — [terraform/README.md](terraform/README.md) · [docs/iac.md](docs/iac.md)
5. **Ansible** `lab-infra.yml` — [ansible/README.md](ansible/README.md)
6. **Ansible** `bastion-ocp-install.yml` — [docs/ansible-ocp-install.md](docs/ansible-ocp-install.md)
7. **Mirror** — [mirror/README.md](mirror/README.md)
8. Boot cluster — [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md)
9. Daily power cycle — [docs/lab-power-cycle.md](docs/lab-power-cycle.md)
10. SSH `core@` from bastion only — [proxmox/access.md](proxmox/access.md)

## Lab progress

- [x] Proxmox + NFS + `vmbr1`
- [x] Infra VMs via Terraform + Ansible
- [x] Mirror OCP 4.22.12 (`oc-mirror` v2)
- [x] compact3 GA **4.22.12** air-gap (baremetal VIP + DNS PTR)
- [x] SNO GA **4.22.12** air-gap (same stack, `ocp_topology=sno`)
- [ ] Virt + LVMS day-2
- [ ] Optional graphical workstation VM

## Target versions

| Component | Version | Status |
|-----------|---------|--------|
| Infra VMs | **RHEL 10.2** | Done |
| OpenShift GA (compact3 / SNO air-gap) | **4.22.12** | Done |
| Proxmox | **9.2.x** | Done — [docs/versions.md](docs/versions.md) |

## Notes

- Secrets (`pull-secret`, keys, kubeconfig, `terraform.tfvars`) are gitignored.
- Copy `*.example` files before use.
- Prefer **Terraform + Ansible** for repeatable rebuilds — [docs/iac.md](docs/iac.md).

# OpenShift Lab on Proxmox (NUC)

Personal training lab for **OpenShift** on **Proxmox** (NUC 15 Pro): air-gap and connected installs, single-node and compact 3-node topologies.

**Language:** this README is in **English** so the project is easier to share. Many deeper guides under `docs/`, `bastion/`, etc. are still in French and will be migrated gradually.

## How deployments work now

| Layer | Tool | Role |
|-------|------|------|
| **VMs** | **Terraform** | Create/recreate Proxmox VMs (separate state per stack) |
| **OS / lab services** | **Ansible** | DVD repos, DNS, registry, bastion network/TLS/clients, install-config |
| **Image mirror** | Manual on bastion | `oc-mirror` (long-running; prepared by Ansible) |
| **Cluster install** | Agent ISO or Assisted UI | Depending on the track below |

Primary entry points:

- Terraform: [terraform/README.md](terraform/README.md)
- Ansible: [ansible/README.md](ansible/README.md)
- IaC overview: [docs/iac.md](docs/iac.md)

Manual runbooks remain useful for debugging; prefer Ansible when a playbook exists (see *Ansible equivalent* blocks in each guide).

## Platform

| Component | Detail |
|-----------|--------|
| Host | NUC 15 Pro — 64 GiB RAM |
| Hypervisor | Proxmox on **internal** 512 GiB SSD |
| VM / ISO storage | NAS NFS |
| Disk layout | Proxmox on internal 512 GiB SSD (moved from USB enclosure → better I/O); Windows kept on internal 1 TiB disk |

## Validated tracks

| Track | Topology | Method | Network | Status |
|-------|----------|--------|---------|--------|
| **OpenShift 4.22 GA** | **SNO** (1 node) | Agent-based air-gap (`oc-mirror` + agent ISO) | Isolated `vmbr1` | Done |
| **OpenShift 5 RC** | **3 nodes** compact | Assisted Installer (connected) | LAN `vmbr0` + home DNS | Done — [assisted-connected](openshift/5-rc/assisted-connected/README.md) |
| **OpenShift 4.21** | **3 nodes** compact | Assisted Installer **air-gap** | Lab mirror + Assisted | Done (procedure to document in-repo) |

Optional / in progress:

- [ ] OpenShift Virtualization + LVMS on air-gap SNO — [docs/openshift-virt-lab.md](docs/openshift-virt-lab.md)
- [ ] Document the 4.21 Assisted air-gap 3-node path in this repository
- [ ] Optional graphical workstation VM

## Network topologies

| Proxmox bridge | Role | Internet |
|----------------|------|----------|
| `vmbr0` | Admin / home LAN | Yes |
| `vmbr1` | Isolated OpenShift lab | **No** |

Lab addressing (`172.16.10.0/24`): [docs/network.md](docs/network.md).

## Lab VMs (air-gap stack)

| VM | Role | Network |
|----|------|---------|
| `bastion` | `oc`, `openshift-install`, `oc-mirror`, orchestration | `vmbr0` + `vmbr1` |
| `dns` | Internal DNS (`dnsmasq`) + NTP | `vmbr1` only |
| `registry` | Mirror registry (OCP images) | `vmbr1` only |
| `ocp-sno` | OpenShift node (agent / SNO) | `vmbr1` only |

Connected Assisted (OCP 5): separate Terraform stack — `ocp-bma-ai-0..2` on `vmbr0` only ([terraform/assisted-ocp-bma/](terraform/assisted-ocp-bma/)).

## Repository layout

```
.
├── docs/                  # Architecture, network, versions, procedures
├── proxmox/               # Network, SSH, RHEL cloud-init templates
├── bastion/               # Bastion notes + scripts
├── openshift/
│   ├── 4.22-ga/           # Agent-based GA (4.22.12) air-gap
│   └── 5-rc/              # RC 5 + Assisted connected
├── dns/                   # DNS service notes
├── mirror/                # oc-mirror procedures
├── terraform/             # lab-airgap + assisted-ocp-bma (separate states)
├── ansible/               # DNS, registry, bastion, OCP install configs
└── versions.env.example   # Version pins (copy → versions.env)
```

## Quick start (air-gap 4.22 SNO)

1. Read [docs/architecture.md](docs/architecture.md)
2. Configure `vmbr1` — [proxmox/network.md](proxmox/network.md)
3. Build RHEL cloud-init templates — [proxmox/rhel-cloudinit-template.md](proxmox/rhel-cloudinit-template.md)
4. **Terraform** VMs — [terraform/lab-airgap/](terraform/lab-airgap/)
5. **Ansible** infra — `ansible-playbook playbooks/lab-infra.yml` ([ansible/README.md](ansible/README.md))
6. **Ansible** OCP configs + agent ISO + upload — `bastion-ocp-install.yml` with `ocp_agent_generate_iso` / `ocp_push_iso_to_proxmox` ([docs/ansible-ocp-install.md](docs/ansible-ocp-install.md))
7. Mirror images on bastion — [mirror/README.md](mirror/README.md) (**before** booting SNO)
8. Boot SNO + wait — [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md)
9. Daily power cycle — [docs/lab-power-cycle.md](docs/lab-power-cycle.md)
10. SSH to SNO (`core@`) **from bastion only** — [docs/sno-ssh-convention.md](docs/sno-ssh-convention.md)

### Connected Assisted (OCP 5, 3 nodes)

Use **only** [terraform/assisted-ocp-bma/](terraform/assisted-ocp-bma/) + [openshift/5-rc/assisted-connected/README.md](openshift/5-rc/assisted-connected/README.md). Do not mix with the air-gap Terraform state.

## Lab progress

- [x] Proxmox + NFS + `vmbr1`
- [x] Infra VMs via **Terraform** (dns / registry / bastion templates)
- [x] Infra + bastion via **Ansible** (`lab-infra`, DVD repo, CA trust, OCP clients)
- [x] Mirror OCP 4.22.12 (`oc-mirror` v2)
- [x] SNO GA **4.22.12** air-gap (agent-based)
- [x] **3-node Assisted connected** — OpenShift **5 RC** (`ocp-bma.home.arpa`)
- [x] **3-node Assisted air-gap** — OpenShift **4.21**
- [ ] Document 4.21 Assisted air-gap path in-repo
- [ ] Virt + LVMS air-gap day-2
- [ ] Optional graphical workstation VM

## Target versions

| Component | Version | Status |
|-----------|---------|--------|
| Infra VMs (dns, registry, bastion) | **RHEL 10.2** | Done |
| OpenShift GA (SNO air-gap) | **4.22.12** | Done |
| OpenShift 5 RC (Assisted connected) | **5.0.0-ec.x** | Done |
| OpenShift 4.21 (Assisted air-gap, 3 nodes) | **4.21.x** | Done (docs TBD) |
| Proxmox | **9.2.x** | Done — [docs/versions.md](docs/versions.md) (stack alignment) |

Details: [docs/versions.md](docs/versions.md)

## Notes

- Secrets (`pull-secret`, keys, kubeconfig, `terraform.tfvars`) are gitignored.
- Copy `*.example` files to local equivalents before use.
- Prefer **Terraform + Ansible** for repeatable rebuilds; keep manual guides as the source of truth when debugging.

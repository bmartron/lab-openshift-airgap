# OpenShift Lab on Proxmox (NUC)

Personal training lab for **OpenShift 4.22 GA** air-gap on **Proxmox** (NUC 15 Pro).

**Current validation:** compact **3-node** (`compact3`). **SNO** uses the same stack — only topology knobs change (`ocp_topology` + generated `install-config` / `agent-config`).

## How deployments work

| Layer | Tool | Role |
|-------|------|------|
| **VMs** | **[Terraform](terraform/README.md)** | Create/recreate Proxmox VMs (`lab-infra` + `lab-ocp`) |
| **OS / lab services** | **[Ansible](ansible/README.md)** | DVD repos, DNS, registry, bastion, install-config / agent-config |
| **Image mirror** | Manual on bastion | `oc-mirror` — [mirror/README.md](mirror/README.md) |
| **Day-1 install** | Agent ISO + `wait-for` | [openshift/4.22-ga/](openshift/4.22-ga/) |
| **Day-2** | Ansible `bastion-ocp-day2.yml` | OperatorHub off, IDMS/ITMS, CatalogSource, OSUS |

Primary entry points:

- **Terraform**: [terraform/README.md](terraform/README.md) · [terraform/lab-infra/README.md](terraform/lab-infra/README.md) · [terraform/lab-ocp/README.md](terraform/lab-ocp/README.md)
- **Ansible**: [ansible/README.md](ansible/README.md)
- **Day-1 / Day-2 detail**: [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md)
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

- [x] Day-2 catalog + OSUS playbook — `bastion-ocp-day2.yml`
- [ ] OpenShift Virtualization + LVMS operators on air-gap — [docs/openshift-virt-lab.md](docs/openshift-virt-lab.md)
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

Prerequisites once: [docs/architecture.md](docs/architecture.md) · [proxmox/network.md](proxmox/network.md) (`vmbr1`) · [proxmox/rhel-cloudinit-template.md](proxmox/rhel-cloudinit-template.md) · copy `*.example` → real files ([docs/iac.md](docs/iac.md)).

Hosts reminder: **Mac** = Ansible/Terraform · **bastion** `bernard@192.168.1.144` · **Proxmox** `root@192.168.1.147` · OCP nodes `core@` **from bastion only** — [proxmox/access.md](proxmox/access.md).

### Day-1 — infra → mirror → boot → Ready

Do **not** boot OCP nodes until the mirror verifies OK (ISO only embeds registry URLs/CA).

| # | Host | What | Detail |
|---|------|------|--------|
| 1 | Mac | Infra VMs | Terraform `lab-infra` then `lab-ocp` — [terraform/README.md](terraform/README.md) |
| 2 | Mac | Lab services | `ansible-playbook playbooks/lab-infra.yml` — [ansible/README.md](ansible/README.md) |
| 3 | Mac | Agent ISO | `all.yml`: ISO flags `true` → `bastion-ocp-install.yml` — [docs/ansible-ocp-install.md](docs/ansible-ocp-install.md) |
| 4 | Bastion | Mirror | `oc-mirror` — [mirror/README.md](mirror/README.md) |
| 5 | Bastion | Verify | `verify-mirror-before-sno.sh` + `lab-startup-check.sh` — no `[FAIL]` |
| 6 | Mac | Boot nodes | `terraform/lab-ocp` → `terraform apply` (agent ISO on NFS CD-ROM) |
| 7 | Bastion | Wait | Restore configs → `agent create cluster-manifests` → `wait-for install-complete` (~30 min) |
| 8 | Bastion | Confirm | `KUBECONFIG=…/auth/kubeconfig` → `oc get nodes` / `oc get co` |

Wait-for (step 7) on bastion:

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
rm -f .openshift_install_state.json
openshift-install agent create cluster-manifests --dir .
openshift-install agent wait-for install-complete --dir . --log-level info
```

Console tunnel (Mac, optional):  
`sudo ssh -L 443:172.16.10.49:443 -L 6443:172.16.10.50:6443 -N bernard@192.168.1.144`

More Day-1 (reinstall, TLS timeout, `ssh-keygen -R`): [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md).

### Day-2 — catalog → OSUS → Virt / LVMS

Cluster must be **Ready**; mirror workspace under `~/lab/4.22-ga/workspace/`.

| # | Host | What | Detail |
|---|------|------|--------|
| 1 | Mac | Day-2 playbook | `bastion-ocp-day2.yml` — OperatorHub off, IDMS/ITMS, CatalogSource, CA, OSUS |
| 2 | Bastion | Verify catalog | `oc get packagemanifest` (lvms / kubevirt / cincinnati) + `oc adm upgrade` |
| 3 | Bastion / UI | Operators | Install **LVMS** then **Virt** from `cs-redhat-operator-index-v4-22` |
| 4 | Bastion | Guest boots | `-e ocp_day2_guest_boots=true` (HCO v1beta1 + CA in cnv) — needs LVMS capacity — [docs/openshift-virt-lab.md](docs/openshift-virt-lab.md) |
| 5 | Bastion | Upgrade (opt.) | Manual: `oc adm upgrade --to=4.22.12` after OSUS is healthy |

Day-2 playbook (Mac):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-day2.yml
# -e ocp_day2_osus=false | -e ocp_day2_install_lvms=true | --tags mirrors,catalog
```

Virt / LVMS details: [docs/openshift-virt-lab.md](docs/openshift-virt-lab.md) · OSUS §5: [openshift/4.22-ga/README.md](openshift/4.22-ga/README.md).

### Daily ops

- Power cycle: [docs/lab-power-cycle.md](docs/lab-power-cycle.md)
- SSH `core@` from bastion only (+ `ssh-keygen -R` after reinstall): [proxmox/access.md](proxmox/access.md)

## Lab progress

- [x] Proxmox + NFS + `vmbr1`
- [x] Infra VMs via Terraform + Ansible
- [x] Mirror OCP 4.22 (`oc-mirror` v2, shortestPath + OSUS graph)
- [x] compact3 / SNO GA air-gap install (baremetal VIP + DNS PTR)
- [x] Day-2 Ansible (OperatorHub / IDMS / catalog / OSUS)
- [ ] Virt + LVMS operators + guest VM tests
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

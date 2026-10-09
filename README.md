# OpenShift Lab on Proxmox (NUC)

Personal **OpenShift 4.22 GA** air-gap lab on Proxmox (NUC 15 Pro).  
**Validated:** compact **3-node** (`compact3`). SNO = same stack (`ocp_topology`).

---

## Official Day 0 / Day 1 / Day 2 (Red Hat)

| Day | Official meaning | Lab checklist |
|-----|------------------|---------------|
| **Day 0** | **Design** — resources & requirements before anything runs | [docs/deploy/DAY0.md](docs/deploy/DAY0.md) |
| **Day 1** | **Deployment** — install, set up, configure | [docs/deploy/DAY1.md](docs/deploy/DAY1.md) |
| **Day 2** | **Operations** — postinstallation (updates, operators, …) | [docs/deploy/DAY2.md](docs/deploy/DAY2.md) |

Sources: [RH blog](https://www.redhat.com/en/blog/how-does-red-hat-support-day-2-operations) · [OCP Day 2](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/postinstallation_configuration/day-2-operations-for-openshift-container-platform-clusters)

| Also | |
|------|--|
| **Architecture** | [docs/architecture/](docs/architecture/) |
| **FAQ** | [docs/faq/README.md](docs/faq/README.md) |
| **Doc hub** | [docs/README.md](docs/README.md) |

---

## Who runs what

| Role | Access |
|------|--------|
| Mac | Terraform + Ansible |
| Proxmox | `root@192.168.1.147` |
| Bastion | `bernard@192.168.1.144` |
| OCP nodes | `core@172.16.10.100`–`.102` from **bastion only** |

[proxmox/access.md](proxmox/access.md)

---

## Tools

| Layer | Path |
|-------|------|
| VMs | [terraform/](terraform/README.md) |
| Config | [ansible/](ansible/README.md) |
| Mirror | [mirror/](mirror/README.md) |

Prefer Terraform + Ansible over hand-edited YAML on the bastion.

---

## Lab at a glance

| | |
|--|--|
| Network | `vmbr0` home · `vmbr1` lab `172.16.10.0/24` |
| VIPs (compact3) | API `.50` · ingress `.49` |
| OCP disks | virtio0 120G + virtio1 100G (`lvms_disk_gb = 100`) |
| Versions | OCP **4.22.12** · [docs/architecture/versions.md](docs/architecture/versions.md) |

```
docs/deploy/     ← Day 0 / 1 / 2
docs/architecture/
docs/faq/
```

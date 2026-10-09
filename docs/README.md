# Lab documentation

## Official Day 0 / Day 1 / Day 2 (Red Hat)

| Day | Official meaning | This lab |
|-----|------------------|----------|
| **Day 0** | **Design** — resources and requirements before anything runs | [deploy/DAY0.md](deploy/DAY0.md) |
| **Day 1** | **Deployment** — install, set up, configure | [deploy/DAY1.md](deploy/DAY1.md) |
| **Day 2** | **Operations** — postinstallation care (updates, operators, …) | [deploy/DAY2.md](deploy/DAY2.md) |

Sources: [Red Hat blog](https://www.redhat.com/en/blog/how-does-red-hat-support-day-2-operations) · [OCP Day 2 operations](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/postinstallation_configuration/day-2-operations-for-openshift-container-platform-clusters)

---

## 1. Deploy (auto)

| Doc | Role |
|-----|------|
| [deploy/DAY0.md](deploy/DAY0.md) | Design checklist |
| [deploy/DAY1.md](deploy/DAY1.md) | Deploy to Ready |
| [deploy/DAY2.md](deploy/DAY2.md) | Catalog, LVMS, Virt, guest boots, upgrades |
| [deploy/iac.md](deploy/iac.md) | Full Terraform + Ansible rebuild notes |
| [deploy/ansible-ocp-install.md](deploy/ansible-ocp-install.md) | Agent ISO / install-config |
| [deploy/openshift-virt-lab.md](deploy/openshift-virt-lab.md) | Virt / LVMS extras |
| [deploy/lab-power-cycle.md](deploy/lab-power-cycle.md) | Daily stop/start |

## 2. Architecture

| Doc | Role |
|-----|------|
| [architecture/architecture.md](architecture/architecture.md) | Lab layout |
| [architecture/network.md](architecture/network.md) | Addressing |
| [architecture/versions.md](architecture/versions.md) | Pinned versions |
| [architecture/bastion.md](architecture/bastion.md) | Bastion dual-NIC |

## 3. FAQ

| Doc | Role |
|-----|------|
| [faq/README.md](faq/README.md) | Aggregated tip index |
| [faq/FAQ.md](faq/FAQ.md) | Full answers |

---

[CHANGELOG.md](CHANGELOG.md) · Tool READMEs: [ansible](../ansible/README.md) · [terraform](../terraform/README.md) · [mirror](../mirror/README.md)

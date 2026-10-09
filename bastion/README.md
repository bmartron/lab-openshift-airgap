# Bastion

Lab orchestration VM (`oc`, `openshift-install`, `oc-mirror`).

| | |
|--|--|
| **Create / size** | Terraform [`lab-infra`](../terraform/lab-infra/) |
| **Configure** | Ansible `lab-infra.yml --limit bastion` — [../ansible/README.md](../ansible/README.md) |
| **Architecture** | Dual-NIC, IPs, routing — [../docs/architecture/bastion.md](../docs/architecture/bastion.md) |
| **Deploy path** | [Day 0](../docs/deploy/DAY0.md) → [Day 1](../docs/deploy/DAY1.md) → [Day 2](../docs/deploy/DAY2.md) |
| **Scripts** | [scripts/README.md](scripts/README.md) → `~/lab/scripts/` via `bastion-scripts.yml` |
| **Tips** | [../docs/faq/README.md](../docs/faq/README.md) |

Do not hand-build this VM in the Proxmox UI for a normal rebuild — use Terraform + Ansible.

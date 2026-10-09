# Ansible — lab configuration

Configures **DNS**, **registry**, and **bastion**; generates OCP install configs / agent ISO; day-2 catalog automation.

**Human path (official Day 0 / 1 / 2):**  
[Day 0 — Design](../docs/deploy/DAY0.md) → [Day 1 — Deployment](../docs/deploy/DAY1.md) → [Day 2 — Operations](../docs/deploy/DAY2.md) · [FAQ](../docs/faq/README.md)

Run from the **Mac** (Proxmox ProxyJump) unless noted.

## Prerequisites

```bash
brew install ansible   # Mac
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
# Set registry_image_tar, registry_data_device, ocp_topology — see examples
```

`bernard` needs sudo: use `--ask-become-pass` (or lab NOPASSWD).

## Playbooks

| Playbook | Role |
|----------|------|
| `playbooks/lab-ssh.yml` | Bastion key → dns/registry + Proxmox; clear stale `known_hosts` |
| `playbooks/lab-infra.yml` | Default: `lab-ssh` then DNS → registry → bastion |
| `playbooks/registry.yml` | Registry host only |
| `playbooks/registry-data-disk.yml` | Data disk `/opt/registry` only |
| `playbooks/bastion-ocp-install.yml` | install-config, agent-config, imageset, CA, pull-secret, optional ISO |
| `playbooks/bastion-ocp-day2.yml` | OperatorHub, IDMS/ITMS, CatalogSource, CA, OSUS; optional LVMS / guest boots |
| `playbooks/bastion-scripts.yml` | Sync `~/lab/scripts/*.sh` only |

Typical Day 1:

```bash
ansible-playbook playbooks/lab-infra.yml --ask-become-pass
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

Typical Day 2:

```bash
ansible-playbook playbooks/bastion-ocp-day2.yml
ansible-playbook playbooks/bastion-ocp-day2.yml -e ocp_day2_install_lvms=true --tags lvms
ansible-playbook playbooks/bastion-ocp-day2.yml -e ocp_day2_guest_boots=true --tags guest_boots
```

ISO / install-config detail: [../docs/deploy/ansible-ocp-install.md](../docs/deploy/ansible-ocp-install.md)  
Pull-secret on Mac: [files/README.md](files/README.md)

## SSH keys

| Key | Source | Used for |
|-----|--------|----------|
| Mac | Terraform `ssh_public_key_file` | Mac → bastion/dns/registry |
| Bastion | `lab-ssh.yml` / `~/.ssh/id_ed25519` | bastion → dns/registry / Proxmox; OCP `sshKey` |

After Mac reboot: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` — [FAQ](../docs/faq/README.md).

## Registry (role summary)

| Parameter | Value |
|-----------|--------|
| IP | `172.16.10.20` — `https://registry.lab.local:5000` |
| Disks | virtio0 OS + virtio1 → `/opt/registry` |
| Image | Local tar via `registry_image_tar` (no Internet pull) |

Variables: `registry_data_device`, `registry_tls_mode`, `registry_image_tar`, `registry_recreate_container`.

## Secrets

- `inventory/hosts.yml`, `inventory/group_vars/all.yml` — gitignored  
- `files/pull-secret.txt`, `files/registry-certs/` — gitignored  

## Related

- Terraform: [../terraform/README.md](../terraform/README.md)  
- Rebuild notes: [../docs/deploy/iac.md](../docs/deploy/iac.md)  
- Bastion architecture: [../docs/architecture/bastion.md](../docs/architecture/bastion.md)

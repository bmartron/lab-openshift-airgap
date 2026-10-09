# Bastion — architecture

Orchestration host: `oc`, `openshift-install`, `oc-mirror`, agent ISO generation.

**Created by** Terraform `lab-infra` · **configured by** Ansible `lab-infra.yml` (not manual Proxmox Create VM).  
Human path: [../deploy/DAY0.md](../deploy/DAY0.md) → [../deploy/DAY1.md](../deploy/DAY1.md)

## Specs

| Parameter | Value |
|-----------|--------|
| Name | `bastion` |
| OS | RHEL 10 |
| vCPU / RAM / disk | 2 / 8 GiB / 40 GiB (NFS) |
| NIC 0 (`vmbr0`) | Admin / Internet — **`192.168.1.144`** (SSH from Mac) |
| NIC 1 (`vmbr1`) | Lab — **`172.16.10.10/24`** |
| Hostname | `bastion.lab.local` |

Access map: [../../proxmox/access.md](../../proxmox/access.md)

## Dual-NIC routing

| Traffic | Path |
|---------|------|
| Lab names (`*.lab.local`) | `/etc/hosts` (Ansible bastion role) + DNS `172.16.10.11` for some lookups |
| Internet (`mirror.openshift.com`, clients download) | Default route via **eth0** / home gateway (`192.168.1.1`) |

Terraform must put the default gateway only on the admin NIC (`ipconfig0`). If the default route is `172.16.10.1` (lab), Internet breaks while the lab registry still answers.

Cloud-init: Ansible sets `manage_etc_hosts: false` so reboot does not wipe the lab `/etc/hosts` block.

Re-apply networking/DNS/CA:

```bash
# Mac
cd ansible && ansible-playbook playbooks/lab-infra.yml --limit bastion --ask-become-pass
```

## Scripts

Synced to `~/lab/scripts/` — [../../bastion/scripts/README.md](../../bastion/scripts/README.md)

## Related

- Network: [network.md](network.md)
- FAQ (routing, `/etc/hosts`): [../faq/README.md](../faq/README.md)

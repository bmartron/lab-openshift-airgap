# Lab VM access (Proxmox)

VMs on `vmbr1` (`172.16.10.0/24`) are **not** reachable directly from the Mac.

| Role | Address |
|------|---------|
| Proxmox (LAN) | `root@192.168.1.147` |
| Bastion (LAN `vmbr0`) | `bernard@192.168.1.144` — SSH/scp **from Mac** |
| Bastion (lab `vmbr1`) | `bernard@172.16.10.10` — from Proxmox / other lab VMs |
| Lab user | `bernard` (cloud-init SSH key from Terraform) |
| Jump | `ProxyJump=root@192.168.1.147` |
| Lab gateway | `172.16.10.1` (Proxmox on `vmbr1`) |

```
Mac (192.168.1.x)
  └── SSH ──► Proxmox (192.168.1.147 + 172.16.10.1)
                └── SSH ──► lab VMs (172.16.10.x)
```

## SSH from the Mac

```bash
# One hop to bastion (LAN)
ssh bernard@192.168.1.144

# Jump to dns / registry
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.11
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20
```

Ansible from the Mac needs **passwordless** `root@192.168.1.147` (otherwise `Permission denied` / port `65535`):

```bash
ssh-copy-id root@192.168.1.147
```

Bernard keys on lab VMs come from Terraform `ssh_public_key_file` (cloud-init) — **Mac** key.
`lab-ssh.yml` (imported by `lab-infra` / `bastion-ocp-install`) also installs the **bastion**
pubkey on dns/registry and clears stale `known_hosts` after VM recreate.

Alternative: run playbooks from the bastion — `ansible/inventory/hosts.from-bastion.yml.example`.

### Recommended `~/.ssh/config`

```text
Host proxmox
  HostName 192.168.1.147
  User root

Host dns-lab
  HostName 172.16.10.11
  User bernard
  ProxyJump proxmox

Host registry-lab
  HostName 172.16.10.20
  User bernard
  ProxyJump proxmox
```

## Proxmox `/etc/hosts` (optional)

Keep **home DNS** in Proxmox `resolv.conf` for updates. Add lab names only — [hosts.lab.example](hosts.lab.example):

```bash
sudo tee -a /etc/hosts << 'EOF'

# Lab OpenShift air-gap
172.16.10.11  dns.lab.local dns
172.16.10.20  registry.lab.local registry
172.16.10.10  bastion.lab.local bastion
172.16.10.100 api.ocp422.lab.local
EOF
```

## OpenShift console from the Mac

| Method | Detail |
|--------|--------|
| SSH tunnel | `sudo ssh -L 443:172.16.10.100:443 -N bernard@192.168.1.144` + Mac `/etc/hosts` apps FQDNs → **`127.0.0.1`** |
| SOCKS | `ssh -D 1080 -N bernard@192.168.1.144` |
| Bastion | Prefer `oc` / console from bastion — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) |

## SNO SSH (`core@`)

**Bastion only** — [docs/sno-ssh-convention.md](../docs/sno-ssh-convention.md).  
VM: [terraform/lab-ocp/vm-nodes.tf](../terraform/lab-ocp/vm-nodes.tf).

## Related

- Network bridge: [network.md](network.md)
- RHEL templates: [rhel-cloudinit-template.md](rhel-cloudinit-template.md)
- Rebuild path: [docs/iac.md](../docs/iac.md)

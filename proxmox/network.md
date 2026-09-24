# Proxmox network (lab)

## Bridge names

Proxmox does **not** allow `-` in interface names.

| Bridge | Role |
|--------|------|
| `vmbr0` | Admin / home LAN |
| `vmbr1` | Isolated OpenShift lab |

## Isolated lab bridge (`vmbr1`)

UI: **System → Network → Create → Linux Bridge**:

| Field | Value |
|-------|--------|
| Name | `vmbr1` |
| IPv4/CIDR | `172.16.10.1/24` |
| Gateway | *(empty)* |
| Bridge ports | *(empty — no physical NIC)* |

Or `/etc/network/interfaces`:

```text
auto vmbr1
iface vmbr1 inet static
    address 172.16.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Apply: `ifreload -a` (on **pve** — `root@192.168.1.147`).

## Rules

- Do **not** set a gateway on `vmbr1`.
- Do **not** NAT `172.16.10.0/24` to the Internet.
- OpenShift / DNS / registry: **one NIC** on `vmbr1` only.
- Bastion: `eth0` → `vmbr0`, `eth1` → `vmbr1`.

## Nested virtualization (OpenShift Virtualization)

On the SNO VM: CPU type **`host`** (Terraform `sno_cpu_type`). Enable nested virt on the Proxmox host if required by your CPU.

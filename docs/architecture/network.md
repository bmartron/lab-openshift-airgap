# Network plan

## Proxmox bridges

### vmbr0 — Admin / home LAN

- Physical NIC on the NUC.
- Proxmox, NFS NAS, bastion `eth0` (prep / Internet).

### vmbr1 — Air-gap lab

- Virtual bridge, **no** physical uplink.
- **No** default route to the Internet.
- All OpenShift lab VMs.

## Addressing — `172.16.10.0/24`

| Hostname / name | IP | Role |
|-----------------|-----|------|
| `proxmox.lab.local` | `172.16.10.1` | Lab gateway on Proxmox (`vmbr1`) |
| `bastion.lab.local` | `172.16.10.10` | Bastion lab NIC |
| `dns.lab.local` | `172.16.10.11` | dnsmasq + NTP |
| `registry.lab.local` | `172.16.10.20` | Mirror registry |
| API VIP (compact3) | `172.16.10.50` | `api` / `api-int` — not a VM |
| Ingress VIP (compact3) | `172.16.10.49` | `*.apps` — not a VM |
| `ocp-master-0` … `-2` | `172.16.10.100`–`.102` | compact3 masters (or SNO on `.100`) |

### DNS records — OpenShift 4.22 GA (compact3)

| FQDN | IP | Notes |
|------|-----|-------|
| `api.ocp422.lab.local` | `172.16.10.50` | API VIP |
| `api-int.ocp422.lab.local` | `172.16.10.50` | Internal API VIP |
| `*.apps.ocp422.lab.local` | `172.16.10.49` | Ingress VIP |
| Host A/PTR | `.100`–`.102` | Node hostnames |

SNO uses `.100` for API/ingress (no VIPs). Deployed by Ansible role `dns` — [../../dns/dnsmasq.conf.example](../../dns/dnsmasq.conf.example).

## Connectivity matrix

| VM | vmbr0 (Internet) | vmbr1 | Talks to |
|----|------------------|-------|----------|
| bastion | Yes (`eth0`) | Yes (`eth1`) | entire lab |
| dns | No | Yes | all lab resolvers |
| registry | No | Yes | bastion + OCP nodes |
| OCP masters | No | Yes | dns + registry |

## Strict air-gap simulation

After prep:

- Disable bastion `eth0`, or
- Remove the default route to the Internet, or
- Firewall: no outbound from `172.16.10.0/24`.

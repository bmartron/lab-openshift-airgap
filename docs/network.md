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

| Hostname | IP | Role |
|----------|-----|------|
| `proxmox.lab.local` | `172.16.10.1` | Lab gateway on Proxmox (`vmbr1`) |
| `bastion.lab.local` | `172.16.10.10` | Bastion lab NIC |
| `dns.lab.local` | `172.16.10.11` | dnsmasq + NTP |
| `registry.lab.local` | `172.16.10.20` | Mirror registry |
| `ocp-sno-422.lab.local` | `172.16.10.100` | OpenShift 4.22 GA SNO |

### DNS records — OpenShift 4.22 GA

| FQDN | IP | Notes |
|------|-----|-------|
| `api.ocp422.lab.local` | `172.16.10.100` | Kubernetes API |
| `api-int.ocp422.lab.local` | `172.16.10.100` | Internal API |
| `*.apps.ocp422.lab.local` | `172.16.10.100` | Ingress wildcard |

Deployed by Ansible role `dns` — [dns/dnsmasq.conf.example](../dns/dnsmasq.conf.example).

## Connectivity matrix

| VM | vmbr0 (Internet) | vmbr1 | Talks to |
|----|------------------|-------|----------|
| bastion | Yes (`eth0`) | Yes (`eth1`) | entire lab |
| dns | No | Yes | all lab resolvers |
| registry | No | Yes | bastion + OCP node |
| OCP SNO | No | Yes | dns + registry |

## Strict air-gap simulation

After prep:

- Disable bastion `eth0`, or
- Remove the default route to the Internet, or
- Firewall: no outbound from `172.16.10.0/24`.

# RHEL 10 cloud-init templates (lab air-gap)

Build once on Proxmox for Terraform clones:

| Template | Datastore | VMs |
|----------|-----------|-----|
| **`rhel10-tpl`** | `local-lvm` | **registry** (`rhel_template`) |
| **`rhel10-nfs`** | `nfs_vm` | **dns**, **bastion** (`rhel_template_infra`) |

Two templates are **required** for the NFS/SSD mix: Telmate does not move UEFI efidisk across storages.

## Prerequisites

| Item | Value |
|------|--------|
| RHEL 10 ISO | `nfs_iso:iso/rhel-10.…-dvd.iso` |
| Firmware | **OVMF + q35** |
| OS disk | **VirtIO Block (`virtio0`)** — Terraform clones as `virtio0` |
| Names | Short (`rhel10-tpl`, `rhel10-nfs`) |

## 1. Source VM → `rhel10-tpl` (`local-lvm`)

- One **~32 GiB** disk on **`local-lvm`** (no data disk)
- CD: RHEL ISO; NIC `vmbr0` (or `vmbr1` + DVD repo)
- Install RHEL **minimal**, lab user, network OK

## 2. Inside the guest (DVD or Internet)

```bash
sudo dnf install -y cloud-init cloud-utils-growpart qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
sudo systemctl enable cloud-init cloud-init-local cloud-config cloud-final
```

## 3. Clean before convert

```bash
sudo cloud-init clean --logs --machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo poweroff
```

## 4. Finalize `rhel10-tpl` on Proxmox

1. Remove CD ISO.
2. Enable **QEMU Guest Agent**.
3. Rename to **`rhel10-tpl`** **before** convert.
4. **Convert to template**.

## 5. Create `rhel10-nfs` (full clone on NAS)

**Host:** `root@192.168.1.147`

```bash
NEXT=$(pvesh get /cluster/nextid)
qm clone 100 "$NEXT" --name rhel10-nfs --full --storage nfs_vm   # adapt VMID of rhel10-tpl
qm template "$NEXT"
qm config "$NEXT" | egrep '^(name|efidisk|virtio)'
# expected: efidisk0 and virtio0 on nfs_vm:...
```

## 6. Terraform

```hcl
storage_infra = "nfs_vm"
storage_perf  = "local-lvm"

rhel_template        = "rhel10-tpl"
rhel_template_infra  = "rhel10-nfs"
registry_install_iso = ""
# ssh_public_key_file = "/Users/YOU/.ssh/id_ed25519.pub"
rhel_dvd_iso         = "nfs_iso:iso/rhel-10.2-x86_64-dvd.iso"
```

```bash
cd terraform/lab-airgap
terraform plan && terraform apply
```

| VM | Template | OS + EFI + cloud-init | Extra |
|----|----------|----------------------|-------|
| dns | `rhel10-nfs` | `nfs_vm` | — |
| bastion | `rhel10-nfs` | `nfs_vm` | dual NIC |
| registry | `rhel10-tpl` | `local-lvm` | **virtio1** 120 GiB → `/dev/vdb` (`/opt/registry`) |
| SNO | — (RHCOS) | `local-lvm` | **virtio0** + optional **virtio1** LVMS + agent ISO |

Rule: **cloud-init on the same datastore as the OS**.

## Notes

- Do **not** convert the registry VM to a template (it has data on `virtio1`).
- After clone, cloud-init applies `ipconfig0` / `ipconfig1`.
- Next: Ansible — [docs/iac.md](../docs/iac.md) · [ansible/README.md](../ansible/README.md).

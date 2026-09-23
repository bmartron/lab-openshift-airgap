# Template RHEL 10 — cloud-init (lab air-gap)

Objectif : templates Proxmox pour Terraform (`clone` + cloud-init) :

| Template | Datastore | VMs |
|----------|-----------|-----|
| **`rhel10-tpl`** | `local-lvm` | **registry** (`rhel_template`) |
| **`rhel10-nfs`** | `nfs_vm` | **dns**, **bastion** (`rhel_template_infra`) |

Deux templates sont **nécessaires** pour le mix NFS/SSD : Telmate ne déplace pas l’EFI UEFI en cross-storage.

## Prérequis

| Élément | Valeur |
|---------|--------|
| ISO RHEL 10 | `nfs_iso:iso/rhel-10.…-dvd.iso` |
| Firmware | **OVMF + q35** |
| Disque OS | **VirtIO Block (`virtio0`)** — Terraform clone en `virtio0` (un `scsi0` créerait un disque vide) |
| Noms | courts (`rhel10-tpl`, `rhel10-nfs`) — limite longueur Proxmox |

## 1. Créer la VM source → `rhel10-tpl` (local-lvm)

- 1 disque **~32 Go** sur **`local-lvm`** (pas de 2ᵉ disque)
- CD : ISO RHEL ; NIC `vmbr0` (ou `vmbr1` + repo DVD)
- Installer RHEL **minimal**, user lab, réseau OK

## 2. Dans l’invité (repo DVD ou Internet)

```bash
sudo dnf install -y cloud-init cloud-utils-growpart qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
sudo systemctl enable cloud-init cloud-init-local cloud-config cloud-final
```

## 3. Nettoyage avant conversion

```bash
sudo cloud-init clean --logs --machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo poweroff
```

## 4. Proxmox — finaliser `rhel10-tpl`

1. Retirer le CD ISO.
2. **QEMU Guest Agent** = enabled.
3. Renommer en **`rhel10-tpl`** **avant** conversion.
4. **Convert to template**.

## 5. Créer `rhel10-nfs` (copie sur NAS)

Sur Proxmox (`root@192.168.1.147`) :

```bash
# VMID du template local (souvent 100)
NEXT=$(pvesh get /cluster/nextid)
qm clone 100 "$NEXT" --name rhel10-nfs --full --storage nfs_vm
qm template "$NEXT"
qm config "$NEXT" | egrep '^(name|efidisk|virtio)'
# attendu : efidisk0 et virtio0 en nfs_vm:...
```

## 6. Terraform

```hcl
storage_infra = "nfs_vm"
storage_perf  = "local-lvm"

rhel_template        = "rhel10-tpl"
rhel_template_infra  = "rhel10-nfs"
registry_install_iso = ""
# ssh_public_key_file = "/Users/VOUS/.ssh/id_ed25519.pub"  # SSH bernard@ depuis le Mac
```

```bash
cd terraform/lab-airgap
terraform plan && terraform apply
```

| VM | Template | OS + EFI + cloud-init | Extra |
|----|----------|----------------------|-------|
| dns | `rhel10-nfs` | `nfs_vm` | — |
| bastion | `rhel10-nfs` | `nfs_vm` | resize possible (lent sur NFS) |
| registry | `rhel10-tpl` | `local-lvm` | **virtio1** 120 Go → `/dev/vdb` |
| SNO | — (RHCOS) | `local-lvm` | scsi0 + scsi1 LVMS + ISO agent |

Règle : **cloud-init sur le même datastore que l’OS** (validé aussi sur `nfs_vm` une fois les templates duals en place).

## Notes

- Ne **pas** convertir la registry en template (elle a `virtio1` données).
- Après clone, cloud-init applique `ipconfig0` / `ipconfig1`.
- Guest agent : souvent OK **sans** Serial Port VirtIO sur RHEL 10 + Proxmox récents.
- En dépannage : après plusieurs changements d’un coup, **revenir en arrière** sur ce qui n’était pas nécessaire une fois le vrai fix identifié (ex. forcer cloud-init en LVM n’était plus requis).

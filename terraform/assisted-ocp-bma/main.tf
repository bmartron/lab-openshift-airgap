locals {
  vm_bios    = "ovmf"
  vm_machine = "q35"
}

resource "proxmox_vm_qemu" "node" {
  count = var.node_count

  name        = "${var.name_prefix}-${count.index}"
  target_node = var.proxmox_node
  agent       = 0
  os_type     = "l26"
  memory      = var.memory_mb

  cpu {
    cores = var.cpu_cores
  }

  bios    = local.vm_bios
  machine = local.vm_machine
  # virtio-scsi-single : iothread valide (évite WARN Proxmox avec virtio-scsi-pci)
  # Dispositifs Linux restent /dev/sda — pas VirtIO Block (/dev/vda)
  scsihw = "virtio-scsi-single"
  # Disque d'abord, ISO ensuite : disque vide → fallback discovery ; OS installé → boot RHCOS
  boot = var.discovery_iso != "" ? "order=scsi0;ide2" : "order=scsi0"

  efidisk {
    storage = var.storage
    efitype = "4m"
  }

  disk {
    slot     = "scsi0"
    size     = "${var.disk_gb}G"
    type     = "disk"
    storage  = var.storage
    iothread = true
  }

  dynamic "disk" {
    for_each = var.extra_disk_gb > 0 ? [1] : []
    content {
      slot     = "scsi1"
      size     = "${var.extra_disk_gb}G"
      type     = "disk"
      storage  = var.storage
      iothread = true
    }
  }

  dynamic "disk" {
    for_each = var.discovery_iso != "" ? [1] : []
    content {
      slot    = "ide2"
      type    = "cdrom"
      iso     = var.discovery_iso
      storage = split(":", var.discovery_iso)[0]
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }

  lifecycle {
    ignore_changes = [network, disk]
  }
}

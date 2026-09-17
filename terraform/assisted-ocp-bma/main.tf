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
  scsihw  = "virtio-scsi-pci"
  boot    = var.discovery_iso != "" ? "order=ide2;scsi0" : "order=scsi0"

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

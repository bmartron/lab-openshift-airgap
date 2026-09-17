# Registry — 172.16.10.20 (vmbr1), scsi0 OS + scsi1 données mirror

resource "proxmox_vm_qemu" "registry" {
  count = var.create_registry ? 1 : 0

  name        = local.vms_registry.name
  target_node = var.proxmox_node
  agent       = 0
  os_type     = "l26"
  memory      = local.vms_registry.memory

  cpu {
    cores = local.vms_registry.cores
  }
  bios    = local.vm_bios
  machine = local.vm_machine
  scsihw  = "virtio-scsi-pci"
  boot    = var.registry_install_iso != "" ? "order=ide2;scsi0" : "order=scsi0"

  efidisk {
    storage = var.storage
    efitype = "4m"
  }

  clone      = var.registry_install_iso == "" ? var.rhel_template : null
  full_clone = var.registry_install_iso == "" ? true : false

  disk {
    slot     = "scsi0"
    size     = "${local.vms_registry.sys_disk_gb}G"
    type     = "disk"
    storage  = var.storage
    iothread = true
  }

  disk {
    slot     = "scsi1"
    size     = "${local.vms_registry.data_disk_gb}G"
    type     = "disk"
    storage  = var.storage
    iothread = true
  }

  dynamic "disk" {
    for_each = var.registry_install_iso != "" ? [1] : []
    content {
      slot    = "ide2"
      type    = "cdrom"
      iso     = var.registry_install_iso
      storage = split(":", var.registry_install_iso)[0]
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.lab_bridge
  }

  ipconfig0 = var.registry_install_iso != "" ? null : "ip=${local.vms_registry.ip}/24,gw=${var.lab_gateway}"

  lifecycle {
    ignore_changes = [network, disk]
  }
}

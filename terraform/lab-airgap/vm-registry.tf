# Registry — 172.16.10.20 (vmbr1)
# Clone : OS virtio0 + données virtio1 + cloud-init ide0.
# Install ISO : scsi0 + scsi1 + efidisk.

resource "proxmox_vm_qemu" "registry" {
  count = var.create_registry ? 1 : 0

  name        = local.vms_registry.name
  target_node = var.proxmox_node
  agent       = var.registry_install_iso != "" ? 0 : 1
  os_type     = var.registry_install_iso != "" ? "l26" : "cloud-init"
  memory      = local.vms_registry.memory

  define_connection_info = false

  cpu {
    cores = local.vms_registry.cores
  }
  bios    = local.vm_bios
  machine = local.vm_machine
  scsihw  = "virtio-scsi-single"
  boot    = var.registry_install_iso != "" ? "order=ide2;scsi0" : "order=virtio0"

  ciuser       = var.registry_install_iso != "" ? null : var.ssh_user
  nameserver   = var.registry_install_iso != "" ? null : var.lab_gateway
  searchdomain = var.registry_install_iso != "" ? null : "lab.local"
  ipconfig0    = var.registry_install_iso != "" ? null : "ip=${local.vms_registry.ip}/24,gw=${var.lab_gateway}"

  dynamic "efidisk" {
    for_each = var.registry_install_iso != "" ? [1] : []
    content {
      storage = var.storage_perf
      efitype = "4m"
    }
  }

  clone      = var.registry_install_iso == "" ? var.rhel_template : null
  full_clone = var.registry_install_iso == "" ? true : false

  dynamic "disk" {
    for_each = var.registry_install_iso == "" ? [1] : []
    content {
      slot     = "virtio0"
      size     = "${local.vms_registry.sys_disk_gb}G"
      type     = "disk"
      storage  = var.storage_perf
      iothread = true
    }
  }

  dynamic "disk" {
    for_each = var.registry_install_iso == "" ? [1] : []
    content {
      slot     = "virtio1"
      size     = "${local.vms_registry.data_disk_gb}G"
      type     = "disk"
      storage  = var.storage_perf
      iothread = true
    }
  }

  dynamic "disk" {
    for_each = var.registry_install_iso == "" ? [1] : []
    content {
      slot    = "ide0"
      type    = "cloudinit"
      storage = var.storage_perf # même datastore que l’OS (local-lvm)
    }
  }

  dynamic "disk" {
    for_each = var.registry_install_iso != "" ? [1] : []
    content {
      slot     = "scsi0"
      size     = "${local.vms_registry.sys_disk_gb}G"
      type     = "disk"
      storage  = var.storage_perf
      iothread = true
    }
  }

  dynamic "disk" {
    for_each = var.registry_install_iso != "" ? [1] : []
    content {
      slot     = "scsi1"
      size     = "${local.vms_registry.data_disk_gb}G"
      type     = "disk"
      storage  = var.storage_perf
      iothread = true
    }
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

  lifecycle {
    ignore_changes = [network, disk]
  }
}

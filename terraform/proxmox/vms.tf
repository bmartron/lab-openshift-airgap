# telmate/proxmox 3.x — Proxmox VE 9 (schéma disque/réseau différent de 2.9)

resource "proxmox_vm_qemu" "dns" {
  count = var.create_dns ? 1 : 0

  name        = local.vms_dns.name
  target_node = var.proxmox_node
  clone       = var.rhel_template
  full_clone  = true
  agent       = 1
  os_type = "cloud-init"
  memory  = local.vms_dns.memory

  cpu {
    cores = local.vms_dns.cores
  }
  scsihw      = "virtio-scsi-pci"
  boot        = "order=scsi0"

  disk {
    slot     = "scsi0"
    size     = "${local.vms_dns.disk_gb}G"
    type     = "disk"
    storage  = var.storage
    iothread = true
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.lab_bridge
  }

  ipconfig0 = "ip=${local.vms_dns.ip}/24,gw=${var.lab_gateway}"

  lifecycle {
    ignore_changes = [network, disk]
  }
}

resource "proxmox_vm_qemu" "registry" {
  count = var.create_registry ? 1 : 0

  name        = local.vms_registry.name
  target_node = var.proxmox_node
  agent       = 0
  os_type = "l26"
  memory  = local.vms_registry.memory

  cpu {
    cores = local.vms_registry.cores
  }
  scsihw      = "virtio-scsi-pci"
  boot        = var.registry_install_iso != "" ? "order=ide2;scsi0" : "order=scsi0"

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

resource "proxmox_vm_qemu" "bastion" {
  count = var.create_bastion ? 1 : 0

  name        = local.vms_bastion.name
  target_node = var.proxmox_node
  clone       = var.rhel_template
  full_clone  = true
  agent       = 1
  os_type = "cloud-init"
  memory  = local.vms_bastion.memory

  cpu {
    cores = local.vms_bastion.cores
  }
  scsihw      = "virtio-scsi-pci"
  boot        = "order=scsi0"

  disk {
    slot     = "scsi0"
    size     = "${local.vms_bastion.disk_gb}G"
    type     = "disk"
    storage  = var.storage
    iothread = true
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.admin_bridge
  }

  network {
    id     = 1
    model  = "virtio"
    bridge = var.lab_bridge
  }

  ipconfig0 = var.bastion_admin_ip != "" ? "ip=${var.bastion_admin_ip}/24" : "ip=dhcp"
  ipconfig1 = "ip=${local.vms_bastion.ip_lab}/24,gw=${var.lab_gateway}"

  lifecycle {
    ignore_changes = [network, disk]
  }
}

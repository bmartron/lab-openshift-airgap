# Bastion — vmbr0 (LAN) + vmbr1 (lab)

resource "proxmox_vm_qemu" "bastion" {
  count = var.create_bastion ? 1 : 0

  name        = local.vms_bastion.name
  target_node = var.proxmox_node
  clone       = var.rhel_template
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  memory      = local.vms_bastion.memory

  cpu {
    cores = local.vms_bastion.cores
  }
  bios    = local.vm_bios
  machine = local.vm_machine
  # virtio-scsi-single : iothread valide (aligné assisted-ocp-bma) — disques /dev/sda
  scsihw = "virtio-scsi-single"
  boot    = "order=scsi0"

  efidisk {
    storage = var.storage
    efitype = "4m"
  }

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

# Bastion — vmbr0 (LAN) + vmbr1 (lab)
# Clone depuis rhel_template_infra (sur nfs_vm) → EFI+OS sur nfs.

resource "proxmox_vm_qemu" "bastion" {
  count = var.create_bastion ? 1 : 0

  name        = local.vms_bastion.name
  target_node = var.proxmox_node
  clone       = var.rhel_template_infra != "" ? var.rhel_template_infra : var.rhel_template
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  memory      = local.vms_bastion.memory

  define_connection_info = false

  cpu {
    cores = local.vms_bastion.cores
  }
  bios    = local.vm_bios
  machine = local.vm_machine
  scsihw  = "virtio-scsi-single"
  boot    = "order=virtio0"

  ciuser       = var.ssh_user
  nameserver   = var.lab_gateway
  searchdomain = "lab.local"
  ipconfig0    = var.bastion_admin_ip != "" ? "ip=${var.bastion_admin_ip}/24" : "ip=dhcp"
  ipconfig1    = "ip=${local.vms_bastion.ip_lab}/24,gw=${var.lab_gateway}"

  disk {
    slot     = "virtio0"
    size     = "${local.vms_bastion.disk_gb}G"
    type     = "disk"
    storage  = var.storage_infra
    format   = "raw"
    iothread = true
  }

  disk {
    slot    = "ide0"
    type    = "cloudinit"
    storage = var.storage_cloudinit
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

  lifecycle {
    ignore_changes = [network, disk]
  }
}

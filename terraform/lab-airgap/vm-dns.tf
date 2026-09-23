# DNS — 172.16.10.11 (vmbr1)
# Clone depuis rhel_template_infra (sur nfs_vm) → EFI+OS restent sur nfs (pas de cross-storage).

resource "proxmox_vm_qemu" "dns" {
  count = var.create_dns ? 1 : 0

  name        = local.vms_dns.name
  target_node = var.proxmox_node
  clone       = var.rhel_template_infra != "" ? var.rhel_template_infra : var.rhel_template
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  memory      = local.vms_dns.memory

  define_connection_info = false

  cpu {
    cores = local.vms_dns.cores
  }
  bios    = local.vm_bios
  machine = local.vm_machine
  scsihw  = "virtio-scsi-single"
  boot    = "order=virtio0"

  ciuser       = var.ssh_user
  sshkeys      = local.sshkeys != "" ? local.sshkeys : null
  nameserver   = var.lab_gateway
  searchdomain = "lab.local"
  ipconfig0    = "ip=${local.vms_dns.ip}/24,gw=${var.lab_gateway}"

  disk {
    slot     = "virtio0"
    size     = "${local.vms_dns.disk_gb}G"
    type     = "disk"
    storage  = var.storage_infra
    format   = "raw"
    iothread = true
  }

  disk {
    slot    = "ide0"
    type    = "cloudinit"
    storage = var.storage_infra # même datastore que l’OS (nfs_vm)
  }

  # Repo dnf air-gap (rôle Ansible rhel_dvd) — boot reste virtio0
  dynamic "disk" {
    for_each = var.rhel_dvd_iso != "" ? [1] : []
    content {
      slot    = "ide2"
      type    = "cdrom"
      iso     = var.rhel_dvd_iso
      storage = split(":", var.rhel_dvd_iso)[0]
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

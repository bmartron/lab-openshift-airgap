# DNS — 172.16.10.11 (vmbr1)

resource "proxmox_vm_qemu" "dns" {
  count = var.create_dns ? 1 : 0

  name        = local.vms_dns.name
  target_node = var.proxmox_node
  clone       = var.rhel_template
  full_clone  = true
  agent       = 1
  os_type     = "cloud-init"
  memory      = local.vms_dns.memory

  cpu {
    cores = local.vms_dns.cores
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

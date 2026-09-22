# SNO OpenShift agent — 172.16.10.100 (vmbr1), ISO agent + disque install + disque LVMS optionnel
# Voir proxmox/sno-vm.md — pas de cloud-init (RHCOS install via ISO)

resource "proxmox_vm_qemu" "sno" {
  count = var.create_sno ? 1 : 0

  name        = var.sno_vm_name
  target_node = var.proxmox_node
  agent       = 0
  os_type     = "l26"
  memory      = var.sno_memory_mb

  cpu {
    cores = var.sno_cpu_cores
    type  = var.sno_cpu_type
  }

  bios    = local.vm_bios
  machine = local.vm_machine
  # virtio-scsi-single : iothread valide (aligné assisted-ocp-bma) — disques /dev/sda
  scsihw = "virtio-scsi-single"
  boot    = var.sno_agent_iso != "" ? "order=ide2;scsi0" : "order=scsi0"

  efidisk {
    storage = var.storage
    efitype = "4m"
  }

  disk {
    slot     = "scsi0"
    size     = "${var.sno_install_disk_gb}G"
    type     = "disk"
    storage  = var.storage
    iothread = true
  }

  dynamic "disk" {
    for_each = var.sno_lvms_disk_gb > 0 ? [1] : []
    content {
      slot     = "scsi1"
      size     = "${var.sno_lvms_disk_gb}G"
      type     = "disk"
      storage  = var.storage
      iothread = true
    }
  }

  dynamic "disk" {
    for_each = var.sno_agent_iso != "" ? [1] : []
    content {
      slot    = "ide2"
      type    = "cdrom"
      iso     = var.sno_agent_iso
      storage = split(":", var.sno_agent_iso)[0]
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

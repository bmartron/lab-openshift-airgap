# SNO OpenShift agent — 172.16.10.100 (vmbr1), agent ISO + install disk + optional LVMS
# No cloud-init (RHCOS via agent ISO) — install: openshift/4.22-ga/README.md

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
  # Disk first, ISO second (same as assisted-ocp-bma): empty disk → fall through to
  # agent ISO; after RHCOS install → boot from virtio0 without re-entering installer.
  scsihw = "virtio-scsi-single"
  boot   = var.sno_agent_iso != "" ? "order=virtio0;ide2" : "order=virtio0"

  efidisk {
    storage = var.storage_perf
    efitype = "4m"
  }

  disk {
    slot     = "virtio0"
    size     = "${var.sno_install_disk_gb}G"
    type     = "disk"
    storage  = var.storage_perf
    iothread = true
  }

  dynamic "disk" {
    for_each = var.sno_lvms_disk_gb > 0 ? [1] : []
    content {
      slot     = "virtio1"
      size     = "${var.sno_lvms_disk_gb}G"
      type     = "disk"
      storage  = var.storage_perf
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
    id      = 0
    model   = "virtio"
    bridge  = var.lab_bridge
    macaddr = var.sno_mac
  }

  lifecycle {
    # Keep disks stable after first create; MAC is managed via sno_mac
    ignore_changes = [disk]
  }
}

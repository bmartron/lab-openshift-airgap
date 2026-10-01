# OpenShift agent VMs — topology sno (1) or compact3 (3)
# No cloud-init / no RHEL clone — empty disks + agent ISO.
# Doc: openshift/4.22-ga/README.md

resource "proxmox_virtual_environment_vm" "node" {
  for_each = local.nodes

  name      = each.value.name
  node_name = var.proxmox_node

  bios          = local.vm_bios
  machine       = local.vm_machine
  scsi_hardware = "virtio-scsi-single"
  started       = true
  on_boot       = true

  # Disk first, ISO second: empty disk → fall through to agent ISO;
  # after RHCOS install → boot from virtio0.
  boot_order = var.agent_iso != "" ? ["virtio0", "ide2"] : ["virtio0"]

  agent {
    enabled = false
  }

  cpu {
    cores = each.value.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  efi_disk {
    datastore_id = var.storage_perf
    type         = "4m"
  }

  disk {
    datastore_id = var.storage_perf
    interface    = "virtio0"
    size         = var.install_disk_gb
    iothread     = true
    discard      = "on"
  }

  dynamic "disk" {
    for_each = var.lvms_disk_gb > 0 ? [1] : []
    content {
      datastore_id = var.storage_perf
      interface    = "virtio1"
      size         = var.lvms_disk_gb
      iothread     = true
      discard      = "on"
    }
  }

  dynamic "cdrom" {
    for_each = var.agent_iso != "" ? [1] : []
    content {
      interface = "ide2"
      file_id   = var.agent_iso
    }
  }

  network_device {
    bridge      = var.lab_bridge
    model       = "virtio"
    mac_address = each.value.mac
  }

  operating_system {
    type = "l26"
  }
}

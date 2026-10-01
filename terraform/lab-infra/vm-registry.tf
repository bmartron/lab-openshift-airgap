# Registry — 172.16.10.20 (vmbr1)
# Linked clone from rhel10-tpl + data disk virtio1.

resource "proxmox_virtual_environment_vm" "registry" {
  count = var.create_registry ? 1 : 0

  name      = local.vms_registry.name
  node_name = var.proxmox_node

  bios          = local.vm_bios
  machine       = local.vm_machine
  scsi_hardware = "virtio-scsi-single"
  started       = true
  on_boot       = true

  agent {
    enabled = true
  }

  clone {
    vm_id = local.template_perf_id
    full  = var.full_clone
  }

  cpu {
    cores = local.vms_registry.cores
    type  = "host"
  }

  memory {
    dedicated = local.vms_registry.memory
  }

  efi_disk {
    datastore_id = var.storage_perf
    type         = "4m"
  }

  disk {
    datastore_id = var.storage_perf
    interface    = "virtio0"
    size         = local.vms_registry.sys_disk_gb
    iothread     = true
    discard      = "on"
  }

  disk {
    datastore_id = var.storage_perf
    interface    = "virtio1"
    size         = local.vms_registry.data_disk_gb
    iothread     = true
    discard      = "on"
  }

  # q35: only ide0/ide2; BPG cloud-init uses ide2 → RHEL DVD on ide0
  dynamic "cdrom" {
    for_each = local.rhel_dvd_file_id != null ? [1] : []
    content {
      interface = "ide0"
      file_id   = local.rhel_dvd_file_id
    }
  }

  network_device {
    bridge = var.lab_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_perf

    dns {
      servers = [var.lab_gateway]
      domain  = "lab.local"
    }

    ip_config {
      ipv4 {
        address = "${local.vms_registry.ip}/24"
        gateway = var.lab_gateway
      }
    }

    user_account {
      username = var.ssh_user
      keys     = local.ssh_keys_list
    }
  }

  operating_system {
    type = "l26"
  }
}

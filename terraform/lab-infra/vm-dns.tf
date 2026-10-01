# DNS — 172.16.10.11 (vmbr1)
# Linked clone from rhel10-nfs (same datastore nfs_vm).

resource "proxmox_virtual_environment_vm" "dns" {
  count = var.create_dns ? 1 : 0

  name      = local.vms_dns.name
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
    vm_id = local.template_infra_id
    full  = var.full_clone
  }

  cpu {
    cores = local.vms_dns.cores
    type  = "host"
  }

  memory {
    dedicated = local.vms_dns.memory
  }

  efi_disk {
    datastore_id = var.storage_infra
    type         = "4m"
  }

  disk {
    datastore_id = var.storage_infra
    interface    = "virtio0"
    size         = local.vms_dns.disk_gb
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
    datastore_id = var.storage_infra

    dns {
      servers = [var.lab_gateway]
      domain  = "lab.local"
    }

    ip_config {
      ipv4 {
        address = "${local.vms_dns.ip}/24"
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

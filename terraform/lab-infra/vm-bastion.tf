# Bastion — vmbr0 (LAN) + vmbr1 (lab)
# Linked clone from rhel10-nfs. Custom user-data: manage_etc_hosts false.

resource "proxmox_virtual_environment_vm" "bastion" {
  count = var.create_bastion ? 1 : 0

  name      = local.vms_bastion.name
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
    cores = local.vms_bastion.cores
    type  = "host"
  }

  memory {
    dedicated = local.vms_bastion.memory
  }

  efi_disk {
    datastore_id = var.storage_infra
    type         = "4m"
  }

  disk {
    datastore_id = var.storage_infra
    interface    = "virtio0"
    size         = local.vms_bastion.disk_gb
    iothread     = true
    discard      = "on"
  }

  dynamic "cdrom" {
    for_each = local.rhel_dvd_file_id != null ? [1] : []
    content {
      interface = "ide2"
      file_id   = local.rhel_dvd_file_id
    }
  }

  network_device {
    bridge = var.admin_bridge
    model  = "virtio"
  }

  network_device {
    bridge = var.lab_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_infra

    dns {
      servers = [var.bastion_admin_dns]
      domain  = "lab.local"
    }

    # eth0 — Internet (vmbr0)
    ip_config {
      ipv4 {
        address = var.bastion_admin_ip != "" ? "${var.bastion_admin_ip}/24" : "dhcp"
        gateway = var.bastion_admin_ip != "" ? var.bastion_admin_gateway : null
      }
    }

    # eth1 — lab (vmbr1), no default gateway
    ip_config {
      ipv4 {
        address = "${local.vms_bastion.ip_lab}/24"
      }
    }

    # Conflicts with user_account — keys/hostname live in the snippet
    user_data_file_id = length(proxmox_virtual_environment_file.bastion_user_data) > 0 ? proxmox_virtual_environment_file.bastion_user_data[0].id : null
  }

  operating_system {
    type = "l26"
  }

  depends_on = [proxmox_virtual_environment_file.bastion_user_data]
}

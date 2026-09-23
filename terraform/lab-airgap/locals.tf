locals {
  # Toutes les VMs lab : aligné Proxmox (q35 + OVMF), template RHEL en UEFI recommandé
  vm_bios    = "ovmf"
  vm_machine = "q35"

  # Clés SSH cloud-init (tfvars ne peut pas appeler file())
  sshkeys = trimspace(
    var.ssh_public_keys != "" ? var.ssh_public_keys : (
      var.ssh_public_key_file != "" ? file(pathexpand(var.ssh_public_key_file)) : ""
    )
  )

  vms_dns = {
    name    = "dns"
    ip      = var.dns_ip
    cores   = 2
    memory  = 2048
    disk_gb = 32
    nics    = [{ bridge = var.lab_bridge }]
  }

  vms_registry = {
    name         = "registry"
    ip           = var.registry_ip
    cores        = 2
    memory       = 4096
    sys_disk_gb  = 32
    data_disk_gb = 120
    nics         = [{ bridge = var.lab_bridge }]
  }

  vms_bastion = {
    name    = "bastion"
    ip_lab  = var.bastion_ip
    cores   = 4
    memory  = 8192
    disk_gb = 64
    nics = [
      { bridge = var.admin_bridge, ip = var.bastion_admin_ip },
      { bridge = var.lab_bridge, ip = var.bastion_ip },
    ]
  }
}

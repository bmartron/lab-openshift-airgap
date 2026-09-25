locals {
  # All lab VMs: Proxmox-aligned (q35 + OVMF); UEFI RHEL template recommended
  vm_bios    = "ovmf"
  vm_machine = "q35"

  # SSH keys for cloud-init (tfvars cannot call file())
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

locals {
  vm_bios    = "ovmf"
  vm_machine = "q35"

  # BPG endpoint must not include /api2/json
  proxmox_endpoint = trimsuffix(replace(var.proxmox_api_url, "/api2/json", ""), "/")

  sshkeys = trimspace(
    var.ssh_public_keys != "" ? var.ssh_public_keys : (
      var.ssh_public_key_file != "" ? file(pathexpand(var.ssh_public_key_file)) : ""
    )
  )

  ssh_keys_list = compact([for k in split("\n", local.sshkeys) : trimspace(k)])

  # Template VM IDs (Proxmox) — override via tfvars if different
  template_infra_id = var.rhel_template_infra_id != null ? var.rhel_template_infra_id : 101 # rhel10-nfs
  template_perf_id  = var.rhel_template_id != null ? var.rhel_template_id : 100             # rhel10-tpl

  # DVD ISO file_id for BPG cdrom (datastore:iso/path)
  rhel_dvd_file_id = var.rhel_dvd_iso != "" ? var.rhel_dvd_iso : null

  vms_dns = {
    name    = "dns"
    ip      = var.dns_ip
    cores   = 2
    memory  = 2048
    disk_gb = 32
  }

  vms_registry = {
    name         = "registry"
    ip           = var.registry_ip
    cores        = 2
    memory       = 4096
    sys_disk_gb  = 32
    data_disk_gb = 120
  }

  vms_bastion = {
    name    = "bastion"
    ip_lab  = var.bastion_ip
    cores   = 4
    memory  = 8192
    disk_gb = 64
  }
}

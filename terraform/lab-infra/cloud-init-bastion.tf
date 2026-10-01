# Bastion user-data snippet (manage_etc_hosts: false) on Proxmox snippets datastore.

resource "proxmox_virtual_environment_file" "bastion_user_data" {
  count = var.create_bastion && length(local.ssh_keys_list) > 0 ? 1 : 0

  node_name    = var.proxmox_node
  datastore_id = var.snippets_datastore
  content_type = "snippets"

  source_raw {
    file_name = "lab-bastion-user.yaml"
    data = templatefile("${path.module}/cloud-init/bastion-user.yaml.tftpl", {
      hostname = local.vms_bastion.name
      fqdn     = "${local.vms_bastion.name}.lab.local"
      user     = var.ssh_user
      ssh_keys = local.ssh_keys_list
    })
  }
}

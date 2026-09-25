locals {
  vm_bios    = "ovmf"
  vm_machine = "q35"

  # Active node map for for_each (exactly one topology)
  nodes = var.ocp_topology == "sno" ? {
    "sno" = {
      name      = var.sno_vm_name
      ip        = var.sno_ip
      mac       = var.sno_mac
      cpu_cores = var.sno_cpu_cores
      memory_mb = var.sno_memory_mb
    }
    } : {
    for k, n in var.compact3_nodes : k => {
      name      = n.name
      ip        = n.ip
      mac       = n.mac
      cpu_cores = var.compact3_cpu_cores
      memory_mb = var.compact3_memory_mb
    }
  }
}

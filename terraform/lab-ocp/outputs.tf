output "ocp_topology" {
  value       = var.ocp_topology
  description = "Active topology: sno or compact3"
}

output "node_vm_ids" {
  value = {
    for k, vm in proxmox_virtual_environment_vm.node : k => vm.vm_id
  }
  description = "Proxmox VM ids keyed by node map key"
}

output "nodes" {
  value = {
    for k, n in local.nodes : k => {
      name = n.name
      ip   = n.ip
      mac  = n.mac
    }
  }
  description = "Planned node name / IP / MAC (for agent-config)"
}

output "next_steps" {
  value = trimspace(join("\n", [
    "Boot agent ISO — openshift/4.22-ga/README.md",
    var.ocp_topology == "compact3" ? "compact3: Ansible ocp_topology=compact3 + DNS" : "sno: match Ansible ocp_sno_mac to nodes.sno.mac",
  ]))
}

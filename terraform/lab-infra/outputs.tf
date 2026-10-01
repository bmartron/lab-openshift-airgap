output "dns_vm_id" {
  value       = var.create_dns ? proxmox_virtual_environment_vm.dns[0].vm_id : null
  description = "Proxmox VM id for dns"
}

output "bastion_vm_id" {
  value       = var.create_bastion ? proxmox_virtual_environment_vm.bastion[0].vm_id : null
  description = "Proxmox VM id for bastion"
}

output "registry_vm_id" {
  value       = var.create_registry ? proxmox_virtual_environment_vm.registry[0].vm_id : null
  description = "Proxmox VM id for registry"
}

output "lab_ips" {
  value = {
    dns      = var.dns_ip
    bastion  = var.bastion_ip
    registry = var.registry_ip
  }
}

output "clone_mode" {
  value       = var.full_clone ? "full" : "linked"
  description = "Clone mode for RHEL VMs (linked = faster)"
}

output "next_steps" {
  value = trimspace(join("\n", compact([
    var.create_dns ? "dns: Ansible playbooks/lab-infra.yml — ansible/README.md" : "",
    var.create_registry ? "registry: Ansible playbooks/lab-infra.yml — ansible/README.md" : "",
    var.create_bastion ? "bastion: Ansible playbooks/lab-infra.yml — ansible/README.md" : "",
    "OCP VMs: terraform/lab-ocp — separate state",
  ])))
}

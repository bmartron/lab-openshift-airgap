output "dns_vm_id" {
  value       = var.create_dns ? proxmox_vm_qemu.dns[0].vmid : null
  description = "ID Proxmox VM dns"
}

output "bastion_vm_id" {
  value       = var.create_bastion ? proxmox_vm_qemu.bastion[0].vmid : null
  description = "ID Proxmox VM bastion"
}

output "registry_vm_id" {
  value       = var.create_registry ? proxmox_vm_qemu.registry[0].vmid : null
  description = "ID Proxmox VM registry"
}

output "sno_vm_id" {
  value       = var.create_sno ? proxmox_vm_qemu.sno[0].vmid : null
  description = "ID Proxmox VM SNO (ocp-sno)"
}

output "lab_ips" {
  value = {
    dns      = var.dns_ip
    bastion  = var.bastion_ip
    registry = var.registry_ip
    sno      = var.sno_ip
  }
}

output "next_steps" {
  value = trimspace(join("\n", compact([
    var.create_dns ? "dns : Ansible playbooks/dns.yml — dns/README.md" : "",
    var.create_registry ? "registry : install RHEL + playbooks/registry.yml — registry/README.md" : "",
    var.create_bastion ? "bastion : playbooks/bastion-preflight.yml — bastion/README.md" : "",
    var.create_sno ? "sno : boot agent ISO — openshift/4.22-ga/README.md" : "",
  ])))
}

output "registry_vm_id" {
  value       = var.create_registry ? proxmox_vm_qemu.registry[0].vmid : null
  description = "ID Proxmox de la VM registry"
}

output "registry_ip" {
  value = var.registry_ip
}

output "next_steps" {
  value = var.create_registry ? "Console Proxmox: install RHEL scsi0, scsi1 pour /opt/registry — registry/README.md" : "registry non créée"
}

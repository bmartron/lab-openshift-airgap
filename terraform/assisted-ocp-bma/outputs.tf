output "vmids" {
  value = [for vm in proxmox_vm_qemu.node : vm.vmid]
}

output "names" {
  value = [for i in range(var.node_count) : "${var.name_prefix}-${i}"]
}

variable "proxmox_api_url" {
  type        = string
  description = "Ex. https://192.168.1.147:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Ex. root@pam!terraform"
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_tls_insecure" {
  type        = bool
  default     = true
  description = "Lab : cert Proxmox auto-signé"
}

variable "proxmox_node" {
  type        = string
  description = "Nom du nœud Proxmox (pve)"
}

variable "storage_infra" {
  type        = string
  default     = "nfs_vm"
  description = "Disques OS dns + bastion (NAS). Cloud-init reste sur storage_cloudinit (LVM)."
}

variable "storage_perf" {
  type        = string
  default     = "local-lvm"
  description = "Disques registry + SNO (SSD local) — mirror / etcd"
}

variable "storage_cloudinit" {
  type        = string
  default     = "local-lvm"
  description = "Drive cloud-init (LVM) — pas nfs_vm (telmate: unable to parse directory volume name)"
}

variable "rhel_template" {
  type        = string
  default     = ""
  description = "Template sur storage_perf (local-lvm) — registry. Ex. rhel10-tpl"
}

variable "rhel_template_infra" {
  type        = string
  default     = ""
  description = "Template sur storage_infra (nfs_vm) — dns/bastion. Ex. rhel10-nfs. Vide = rhel_template"
}

variable "registry_install_iso" {
  type        = string
  default     = ""
  description = "ISO RHEL sur Proxmox, ex. nfs_iso:iso/rhel-10.iso — création registry sans clone (install Anaconda)"
}

variable "create_dns" {
  type    = bool
  default = false
}

variable "create_bastion" {
  type    = bool
  default = false
}

variable "create_registry" {
  type    = bool
  default = true
}

variable "lab_bridge" {
  type    = string
  default = "vmbr1"
}

variable "admin_bridge" {
  type    = string
  default = "vmbr0"
}

variable "lab_gateway" {
  type    = string
  default = "172.16.10.1"
}

variable "lab_dns" {
  type    = string
  default = "172.16.10.11"
}

variable "dns_ip" {
  type    = string
  default = "172.16.10.11"
}

variable "bastion_ip" {
  type    = string
  default = "172.16.10.10"
}

variable "registry_ip" {
  type    = string
  default = "172.16.10.20"
}

variable "sno_ip" {
  type        = string
  default     = "172.16.10.100"
  description = "IP lab SNO (documentation / outputs — pas appliquée par Terraform sur RHCOS)"
}

variable "bastion_admin_ip" {
  type        = string
  description = "IP bastion sur vmbr0 (LAN) — pour SSH depuis le Mac"
  default     = ""
}

variable "ssh_user" {
  type    = string
  default = "bernard"
}

# --- SNO agent-based (OpenShift 4.22 GA lab) ---

variable "create_sno" {
  type        = bool
  default     = false
  description = "VM ocp-sno sur vmbr1 — false si VM déjà manuelle (éviter recréation)"
}

variable "sno_vm_name" {
  type    = string
  default = "ocp-sno"
}

variable "sno_agent_iso" {
  type        = string
  default     = ""
  description = "ISO agent bastion → nfs_iso, ex. nfs_iso:iso/agent.x86_64.iso"
}

variable "sno_install_disk_gb" {
  type    = number
  default = 120
}

variable "sno_lvms_disk_gb" {
  type        = number
  default     = 100
  description = "2e disque scsi1 pour LVMS (/dev/sdb) — 0 pour désactiver"
}

variable "sno_cpu_cores" {
  type    = number
  default = 8
}

variable "sno_cpu_type" {
  type        = string
  default     = "host"
  description = "host pour nested virt (OpenShift Virtualization sur SNO)"
}

variable "sno_memory_mb" {
  type    = number
  default = 32768
}

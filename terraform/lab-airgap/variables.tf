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

variable "storage" {
  type        = string
  description = "Datastore disques VM Proxmox (ex. nfs_vm)"
}

variable "rhel_template" {
  type        = string
  default     = ""
  description = "Template Proxmox (clone) — idéalement q35 + OVMF comme les VMs Terraform. Vide si registry_install_iso est défini."
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

variable "bastion_admin_ip" {
  type        = string
  description = "IP bastion sur vmbr0 (LAN) — pour SSH depuis le Mac"
  default     = ""
}

variable "ssh_user" {
  type    = string
  default = "bernard"
}

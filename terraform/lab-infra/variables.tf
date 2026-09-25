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
  description = "Lab: self-signed Proxmox cert"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name (pve)"
}

variable "storage_infra" {
  type        = string
  default     = "nfs_vm"
  description = "OS + EFI + cloud-init for dns/bastion (same datastore as rhel10-nfs)"
}

variable "storage_perf" {
  type        = string
  default     = "local-lvm"
  description = "OS + EFI + cloud-init + registry data (same datastore as rhel10-tpl)"
}

variable "rhel_template" {
  type        = string
  default     = ""
  description = "Template on storage_perf (local-lvm) — registry. Ex. rhel10-tpl"
}

variable "rhel_template_infra" {
  type        = string
  default     = ""
  description = "Template on storage_infra (nfs_vm) — dns/bastion. Ex. rhel10-nfs. Empty = rhel_template"
}

variable "registry_install_iso" {
  type        = string
  default     = ""
  description = "RHEL ISO on Proxmox, ex. nfs_iso:iso/rhel-10.iso — registry without clone (Anaconda)"
}

variable "rhel_dvd_iso" {
  type        = string
  default     = ""
  description = "Full RHEL DVD (BaseOS+AppStream) on ide2 after clone — air-gap dnf repo. Ex. nfs_iso:iso/rhel-10.2-x86_64-dvd.iso. Empty = no CD."
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
  description = "Bastion IP on vmbr0 (LAN) — SSH from Mac"
  default     = ""
}

variable "bastion_admin_dns" {
  type        = string
  default     = "192.168.1.1"
  description = "Internet DNS (home LAN) for bastion cloud-init — not lab gateway 172.16.10.1"
}

variable "bastion_admin_gateway" {
  type        = string
  default     = "192.168.1.1"
  description = "Internet gateway (home LAN) on eth0/vmbr0 — lab NIC must NOT have a default gateway"
}

variable "ssh_user" {
  type    = string
  default = "bernard"
}

variable "ssh_public_keys" {
  type        = string
  default     = ""
  description = "Public key(s) inline (one per line). Takes precedence over ssh_public_key_file."
}

variable "ssh_public_key_file" {
  type        = string
  default     = ""
  description = "Path to a .pub file (ex. /Users/…/.ssh/id_ed25519.pub) — read via file() in locals"
}

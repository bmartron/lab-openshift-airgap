variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_tls_insecure" {
  type    = bool
  default = true
}

variable "proxmox_node" {
  type = string
}

variable "storage" {
  type = string
}

variable "node_count" {
  type    = number
  default = 3
}

variable "name_prefix" {
  type    = string
  default = "ocp-bma-ai"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "discovery_iso" {
  type        = string
  description = "ex. nfs_iso:iso/ocp-bma-discovery.iso"
}

variable "cpu_cores" {
  type    = number
  default = 8
}

variable "memory_mb" {
  type        = number
  default     = 24576
  description = "24 GiB = 24576"
}

variable "disk_gb" {
  type        = number
  default     = 120
  description = "Disque install OpenShift (scsi0)"
}

variable "extra_disk_gb" {
  type        = number
  default     = 50
  description = "2e disque scsi1 (0 = désactivé)"
}

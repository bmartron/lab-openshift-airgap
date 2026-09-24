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
  description = "OS + EFI + cloud-init dns/bastion (même datastore que rhel10-nfs)"
}

variable "storage_perf" {
  type        = string
  default     = "local-lvm"
  description = "OS + EFI + cloud-init + données registry/SNO (même datastore que rhel10-tpl)"
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

variable "rhel_dvd_iso" {
  type        = string
  default     = ""
  description = "DVD RHEL complet (BaseOS+AppStream) en ide2 après clone — repo dnf air-gap. Ex. nfs_iso:iso/rhel-10.2-x86_64-dvd.iso. Vide = pas de CD."
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
  description = "Lab SNO IP (docs / outputs — not applied by Terraform on RHCOS)"
}

variable "sno_mac" {
  type        = string
  default     = "BC:24:11:E1:8F:82"
  description = "Fixed VirtIO NIC MAC — must match Ansible ocp_sno_mac / agent-config"
}

variable "bastion_admin_ip" {
  type        = string
  description = "IP bastion sur vmbr0 (LAN) — pour SSH depuis le Mac"
  default     = ""
}

variable "bastion_admin_dns" {
  type        = string
  default     = "192.168.1.1"
  description = "DNS Internet (LAN maison) pour cloud-init bastion — pas le gateway lab 172.16.10.1"
}

variable "bastion_admin_gateway" {
  type        = string
  default     = "192.168.1.1"
  description = "Gateway Internet (LAN maison) sur eth0/vmbr0 — la NIC lab ne doit PAS avoir de gateway par défaut"
}

variable "ssh_user" {
  type    = string
  default = "bernard"
}

variable "ssh_public_keys" {
  type        = string
  default     = ""
  description = "Clé(s) publique(s) en clair (une par ligne). Prioritaire sur ssh_public_key_file."
}

variable "ssh_public_key_file" {
  type        = string
  default     = ""
  description = "Chemin vers un fichier .pub (ex. /Users/…/.ssh/id_ed25519.pub) — lu via file() dans locals"
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
  description = "2nd VirtIO disk virtio1 for LVMS (/dev/vdb) — 0 to disable"
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

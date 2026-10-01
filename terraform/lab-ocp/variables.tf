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

variable "storage_perf" {
  type        = string
  default     = "local-lvm"
  description = "OS disks + EFI for OCP nodes"
}

variable "lab_bridge" {
  type    = string
  default = "vmbr1"
}

variable "ocp_topology" {
  type        = string
  description = "Cluster shape: sno (1 node) or compact3 (3 control-plane nodes)"

  validation {
    condition     = contains(["sno", "compact3"], var.ocp_topology)
    error_message = "ocp_topology must be \"sno\" or \"compact3\"."
  }
}

variable "agent_iso" {
  type        = string
  default     = ""
  description = "Agent ISO on Proxmox, ex. nfs_iso:iso/agent.x86_64.iso. Empty = no CD-ROM."
}

variable "install_disk_gb" {
  type    = number
  default = 120
}

variable "lvms_disk_gb" {
  type        = number
  default     = 100
  description = "2nd VirtIO disk virtio1 for LVMS (/dev/vdb) — 0 to disable"
}

variable "cpu_type" {
  type        = string
  default     = "host"
  description = "host for nested virt (OpenShift Virtualization)"
}

# --- SNO defaults (used when ocp_topology = sno) ---

variable "sno_vm_name" {
  type    = string
  default = "ocp-sno"
}

variable "sno_ip" {
  type        = string
  default     = "172.16.10.100"
  description = "Lab SNO IP (docs / outputs — not applied by Terraform on RHCOS)"
}

variable "sno_mac" {
  type        = string
  default     = "bc:24:11:e1:8f:82"
  description = "Fixed VirtIO NIC MAC — must match Ansible ocp_sno_mac / agent-config"
}

variable "sno_cpu_cores" {
  type    = number
  default = 8
}

variable "sno_memory_mb" {
  type    = number
  default = 24576
}

# --- compact3 defaults (used when ocp_topology = compact3) ---

variable "compact3_nodes" {
  type = map(object({
    name = string
    ip   = string
    mac  = string
  }))
  default = {
    "0" = {
      name = "ocp-master-0"
      ip   = "172.16.10.100"
      mac  = "bc:24:11:e1:8f:82"
    }
    "1" = {
      name = "ocp-master-1"
      ip   = "172.16.10.101"
      mac  = "bc:24:11:e1:8f:83"
    }
    "2" = {
      name = "ocp-master-2"
      ip   = "172.16.10.102"
      mac  = "bc:24:11:e1:8f:84"
    }
  }
  description = "Three control-plane nodes — IPs/MACs for agent-config (Ansible follow-up)"
}

variable "compact3_cpu_cores" {
  type    = number
  default = 8
}

variable "compact3_memory_mb" {
  type    = number
  default = 16384
}

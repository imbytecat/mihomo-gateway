# Proxmox API Configuration
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://pve.example.com:8006/api2/json)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., user@pam!token-name)"
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to build on"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification for Proxmox API"
  default     = false
}

# ISO Configuration
variable "proxmox_iso_file" {
  type        = string
  description = "Path to Debian ISO on Proxmox storage (e.g., local:iso/debian-12.8.0-amd64-netinst.iso)"
}

variable "proxmox_iso_storage" {
  type        = string
  description = "Proxmox storage pool for ISO files"
  default     = "local"
}

# VM Storage Configuration
variable "proxmox_storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "local-lvm"
}

# VM Configuration
variable "vm_id" {
  type        = number
  description = "VM template ID in Proxmox"
  default     = 9000
}

variable "vm_name" {
  type        = string
  description = "VM template name"
  default     = "debian-gateway"
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "vm_memory" {
  type        = number
  description = "Memory in MB"
  default     = 512
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size (e.g., 16G)"
  default     = "16G"
}

# SSH Configuration
variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "packer"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning"
  sensitive   = true
}

variable "ssh_timeout" {
  type        = string
  description = "SSH connection timeout"
  default     = "30m"
}

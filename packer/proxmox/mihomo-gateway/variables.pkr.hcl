# =============================================================================
# Proxmox API Configuration (required for proxmox-iso builder)
# =============================================================================
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://pve.example.com:8006/api2/json)"
  default     = ""
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., user@pam!token-name)"
  default     = ""
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
  default     = ""
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to build on"
  default     = "pve"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification for Proxmox API"
  default     = false
}

# =============================================================================
# ISO Configuration
# =============================================================================

# For Proxmox builder: path on Proxmox storage
variable "proxmox_iso_file" {
  type        = string
  description = "Path to Debian ISO on Proxmox storage (e.g., local:iso/debian-12.8.0-amd64-netinst.iso)"
  default     = "local:iso/debian-12.8.0-amd64-netinst.iso"
}

variable "proxmox_iso_storage" {
  type        = string
  description = "Proxmox storage pool for ISO files"
  default     = "local"
}

# For QEMU builder: URL to download ISO
variable "iso_url" {
  type        = string
  description = "URL to download Debian ISO (for QEMU builder)"
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "ISO checksum (for QEMU builder)"
  default     = "sha256:04396d12b0f377958a070c38a923c227832fa3b3e18ddc013936ecf492e9fbb3"
}

# =============================================================================
# VM Storage Configuration
# =============================================================================
variable "proxmox_storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "local-lvm"
}

# =============================================================================
# VM Configuration
# =============================================================================
variable "vm_id" {
  type        = number
  description = "VM template ID in Proxmox"
  default     = 9000
}

variable "vm_name" {
  type        = string
  description = "VM template name"
  default     = "mihomo-gateway"
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

# =============================================================================
# SSH Configuration
# =============================================================================
variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "packer"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning"
  sensitive   = true
  default     = "packer"
}

variable "ssh_timeout" {
  type        = string
  description = "SSH connection timeout"
  default     = "30m"
}

# =============================================================================
# QEMU Builder Configuration
# =============================================================================
variable "headless" {
  type        = bool
  description = "Run QEMU in headless mode (no GUI)"
  default     = true
}

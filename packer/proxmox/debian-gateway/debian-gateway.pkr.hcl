packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "debian-gateway" {
  # Proxmox API Configuration
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM Configuration
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_description = "Debian 12 Gateway VM with Mihomo transparent proxy - Built by Packer"

  # ISO Configuration
  iso_file         = var.proxmox_iso_file
  iso_storage_pool = var.proxmox_iso_storage
  unmount_iso      = true

  # Hardware Configuration
  cores    = var.vm_cores
  memory   = var.vm_memory
  cpu_type = "host"
  os       = "l26"
  bios     = "ovmf"
  machine  = "q35"

  # EFI Configuration
  efi_config {
    efi_storage_pool  = var.proxmox_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # Disk Configuration
  disks {
    type              = "scsi"
    disk_size         = var.vm_disk_size
    storage_pool      = var.proxmox_storage_pool
    format            = "raw"
  }

  scsi_controller = "virtio-scsi-single"

  # Network Configuration
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # QEMU Guest Agent
  qemu_agent = true

  # Cloud-Init (for post-deployment configuration)
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage_pool

  # Boot Configuration
  boot         = "order=scsi0;ide2"
  boot_wait    = "5s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=${var.vm_name} ",
    "domain=localdomain ",
    "interface=auto ",
    "passwd/username=${var.ssh_username} ",
    "passwd/user-password=${var.ssh_password} ",
    "passwd/user-password-again=${var.ssh_password} ",
    "<enter>"
  ]

  # HTTP Server for preseed
  http_directory = "http"
  http_port_min  = 8100
  http_port_max  = 8150

  # SSH Configuration
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = var.ssh_timeout
  ssh_handshake_attempts = 100
}

build {
  name    = "debian-gateway"
  sources = ["source.proxmox-iso.debian-gateway"]

  # Copy configuration files to VM
  provisioner "file" {
    source      = "files/"
    destination = "/tmp/files"
  }

  # Install Mihomo
  provisioner "shell" {
    script = "scripts/install-mihomo.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  # Configure sysctl
  provisioner "shell" {
    script = "scripts/configure-sysctl.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  # Configure nftables
  provisioner "shell" {
    script = "scripts/configure-nftables.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  # Configure routing
  provisioner "shell" {
    script = "scripts/configure-routing.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }

  # Cleanup for template
  provisioner "shell" {
    script = "scripts/cleanup.sh"
    execute_command = "sudo bash '{{ .Path }}'"
  }
}

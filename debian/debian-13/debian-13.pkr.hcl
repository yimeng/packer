packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Pull Proxmox secrets from Vault (see README for env.sh setup).
# Alternatively, override via -var or *.auto.pkrvars.hcl files.
locals {
  proxmox_url      = vault("secrets/proxmox", "url")
  proxmox_username = vault("secrets/proxmox", "username")
  proxmox_token    = vault("secrets/proxmox", "token")
}

variable "proxmox_node" {
  type    = string
  default = "homelab"
}

variable "http_bind_address" {
  type    = string
  default = "0.0.0.0"
}

variable "http_host" {
  type        = string
  description = "Host/IP the installer uses to fetch preseed.cfg. Must be reachable from the VM during build."
  default     = "CHANGE_ME"
}

variable "ssh_username" {
  type    = string
  default = "yimeng"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to authorize for root and ssh_username."
  sensitive   = true
}

variable "iso_file" {
  type    = string
  default = "local:iso/debian-13.5.0-amd64-netinst.iso"
}

locals {
  preseed = templatefile("${path.root}/http/preseed.cfg.tmpl", {
    ssh_username   = var.ssh_username
    ssh_password   = var.ssh_password
    ssh_public_key = var.ssh_public_key
  })
}

source "proxmox-iso" "debian_13" {
  proxmox_url              = local.proxmox_url
  username                 = local.proxmox_username
  token                    = local.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id                 = 9000
  vm_name               = "debian-13-clean-template"
  template_name         = "debian-13-clean-template"
  template_description  = "Clean Debian 13 template: ${var.ssh_username} user, SSH key, qemu guest agent, common shell aliases, Tsinghua mirror."
  tags                  = "debian;template;packer"
  qemu_agent            = true
  os                    = "l26"

  iso_file    = var.iso_file
  unmount_iso = true

  cores    = 2
  sockets  = 1
  memory   = 2048
  cpu_type = "host"
  bios     = "seabios"
  machine  = "q35"

  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = "local-lvm"
    format       = "raw"
    cache_mode   = "none"
    io_thread    = true
    discard      = true
  }

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr1"
    firewall = false
  }

  http_bind_address     = var.http_bind_address
  http_network_protocol = "tcp"
  http_port_min         = 8765
  http_port_max         = 8765
  http_content = {
    "/preseed.cfg" = local.preseed
  }

  boot_wait = "8s"
  boot_command = [
    "<esc><wait>",
    "auto ",
    "url=http://${var.http_host}:{{ .HTTPPort }}/preseed.cfg ",
    "debian-installer=en_US.UTF-8 ",
    "locale=en_US.UTF-8 ",
    "keyboard-configuration/xkb-keymap=us ",
    "netcfg/get_hostname=debian-template ",
    "netcfg/get_domain=lan ",
    "fb=false ",
    "debconf/frontend=noninteractive ",
    "console-setup/ask_detect=false ",
    "<enter>"
  ]

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "45m"
}

build {
  sources = ["source.proxmox-iso.debian_13"]
}

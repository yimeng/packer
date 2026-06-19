packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

locals {
  boot_command = ["<esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"]
  date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))

  proxmox_url      = vault("secrets/proxmox", "url")
  proxmox_username = vault("secrets/proxmox", "username")
  proxmox_token    = vault("secrets/proxmox", "token")
}

variable "proxmox_node" {
  type    = string
  default = "homelab"
}

variable "iso_file" {
  type    = string
  default = "local:iso/debian-11.6.0-amd64-DVD-1.iso"
}

variable "bridge" {
  type        = string
  description = "Proxmox bridge to attach the build VM to."
  default     = "vmbr1"
}

variable "http_interface" {
  type        = string
  description = "Local interface Packer uses to serve preseed. Set to your build host's reachable interface."
  default     = "CHANGE_ME"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  description = "Password for the default user during build. Will NOT be committed; provide via *.auto.pkrvars.hcl."
}

variable "vm_id" {
  type    = number
  default = 9003
}

source "proxmox-iso" "debian" {
  proxmox_url              = local.proxmox_url
  username                 = local.proxmox_username
  token                    = local.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id                 = var.vm_id
  vm_name               = "debian-11-template"
  template_name         = "debian-11-template"
  template_description  = "Debian 11 x86_64 template built with Packer on ${local.date}"
  tags                  = "debian;template;packer"
  qemu_agent            = true
  os                    = "l26"

  boot_command = local.boot_command
  boot_wait    = "3s"

  http_directory           = "cloud-init"
  http_interface           = var.http_interface
  insecure_skip_tls_verify = true
  iso_file                 = var.iso_file
  unmount_iso              = false

  cores    = 4
  sockets  = 1
  memory   = 8192
  cpu_type = "host"
  bios     = "seabios"
  machine  = "q35"

  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "60G"
    storage_pool = "local-lvm"
    format       = "raw"
    cache_mode   = "none"
    io_thread    = true
    discard      = true
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.bridge
    firewall = false
  }

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"
}

build {
  name = "build"
  sources = ["source.proxmox-iso.debian"]

  provisioner "shell" {
    inline = [
      "sudo env > ~/packer.env",
      "exit 0",
    ]
  }
}

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

locals {
  date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))

  # Pull Proxmox secrets from Vault (see README for env.sh setup).
  proxmox_url      = vault("secrets/proxmox", "url")
  proxmox_username = vault("secrets/proxmox", "username")
  proxmox_token    = vault("secrets/proxmox", "token")

  user_data = templatefile("${path.root}/cloud-init/user-data.tmpl", {
    ssh_username      = var.ssh_username
    ssh_password_hash = var.ssh_password_hash
    ssh_public_keys   = var.ssh_public_keys
  })
}

variable "proxmox_node" {
  type    = string
  default = "homelab"
}

variable "iso_file" {
  type    = string
  default = "local:iso/ubuntu-24.04-live-server-amd64.iso"
}

variable "bridge" {
  type        = string
  description = "Proxmox bridge to attach the build VM to."
  default     = "vmbr1"
}

variable "http_interface" {
  type        = string
  description = "Local interface Packer uses to serve cloud-init. Set to your build host's reachable interface."
  default     = "CHANGE_ME"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password_hash" {
  type        = string
  sensitive   = true
  description = "SHA-512 password hash for the default user. Generate with: mkpasswd --method=sha-512 --rounds=4096"
}

variable "ssh_public_keys" {
  type        = list(string)
  sensitive   = true
  description = "List of SSH public keys to authorize for the default user."
}

variable "vm_id" {
  type    = number
  default = 9004
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = local.proxmox_url
  username                 = local.proxmox_username
  token                    = local.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id                 = var.vm_id
  vm_name               = "ubuntu-24.04-template"
  template_name         = "ubuntu-24.04-template"
  template_description  = "Ubuntu 24.04 LTS template built with Packer on ${local.date}"
  tags                  = "ubuntu;template;packer"
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
    bridge   = var.bridge
    firewall = false
  }

  http_interface        = var.http_interface
  http_network_protocol = "tcp"
  http_content = {
    "/meta-data" = ""
    "/user-data" = local.user_data
  }

  boot_wait = "5s"
  boot_command = [
    "<esc><esc><esc><esc>e<wait>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\"<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>",
    "<enter><f10><wait>"
  ]

  ssh_username = var.ssh_username
  ssh_password = ""
  ssh_timeout  = "30m"
}

build {
  sources = ["source.proxmox-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo truncate -s 0 /etc/machine-id",
      "exit 0",
    ]
  }
}

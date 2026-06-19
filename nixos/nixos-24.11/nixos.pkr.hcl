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

  proxmox_url      = vault("secrets/proxmox", "url")
  proxmox_username = vault("secrets/proxmox", "username")
  proxmox_token    = vault("secrets/proxmox", "token")

  configuration = templatefile("${path.root}/configuration.nix.tpl", {
    ssh_username   = var.ssh_username
    ssh_public_key = var.ssh_public_key
    hostname       = var.hostname
  })
}

variable "proxmox_node" {
  type    = string
  default = "homelab"
}

variable "iso_file" {
  type    = string
  default = "local:iso/nixos-minimal-24.11pre705705.11ff16831f1a-x86_64-linux.iso"
}

variable "bridge" {
  type        = string
  description = "Proxmox bridge to attach the build VM to."
  default     = "vmbr1"
}

variable "ssh_username" {
  type    = string
  default = "yimeng"
}

variable "ssh_public_key" {
  type        = string
  sensitive   = true
  description = "SSH public key to authorize for the default user."
}

variable "hostname" {
  type    = string
  default = "nixos-template"
}

variable "vm_id" {
  type    = number
  default = 9010
}

variable "live_root_password" {
  type      = string
  sensitive = true
  default   = "packer"
}

source "proxmox-iso" "nixos" {
  proxmox_url              = local.proxmox_url
  username                 = local.proxmox_username
  token                    = local.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id                 = var.vm_id
  vm_name               = "nixos-24.11-template"
  template_name         = "nixos-24.11-template"
  template_description  = "NixOS 24.11 template built with Packer on ${local.date}"
  tags                  = "nixos;template;packer"
  qemu_agent            = true
  os                    = "l26"

  iso_file    = var.iso_file
  unmount_iso = true

  cores    = 2
  sockets  = 1
  memory   = 4096
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

  boot_wait = "10s"
  boot_command = [
    "<enter><wait5>",
    "root<enter><wait5>",
    "echo 'root:${var.live_root_password}' | chpasswd<enter><wait5>",
    "systemctl start sshd<enter><wait5>",
  ]

  ssh_username = "root"
  ssh_password = var.live_root_password
  ssh_timeout  = "30m"
}

build {
  sources = ["source.proxmox-iso.nixos"]

  provisioner "file" {
    destination = "/tmp/configuration.nix"
    content     = local.configuration
  }

  provisioner "file" {
    destination = "/tmp/install-nixos.sh"
    source      = "${path.root}/install-nixos.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install-nixos.sh",
      "bash /tmp/install-nixos.sh",
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    inline = [
      "echo 'NixOS installation verified'",
      "nixos-version",
    ]
    pause_before = "30s"
  }
}

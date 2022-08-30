locals {
  boot_command = ["<esc><esc><esc><esc>e<wait>",
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
#        "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"<enter><wait>",
        "linux /casper/vmlinuz --- autoinstall url=/cdrom/  ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"<enter><wait>",
        "initrd /casper/initrd<enter><wait>",
        "boot<enter>",
        "<enter><f10><wait>"]
}

locals {
    date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))
}

locals {
    proxmox_username = vault("secrets/proxmox", "username")
    proxmox_password = vault("secrets/proxmox", "password")
    proxmox_url = vault("secrets/proxmox", "url")
    sensitive  = true
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}
# user-data identity password
variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

variable "iso_file" {
  type    = string
  default = "local:iso/ubuntu-22.04-live-server-amd64.iso"
}



source "proxmox" "ubuntu" {
  username             = "${local.proxmox_username}"
  password             = "${local.proxmox_password}"
  proxmox_url          = "${local.proxmox_url}"

  boot_command =  "${local.boot_command}"
  boot_wait    = "3s"

  http_directory           = "cloud-init"
  http_interface           = "en0"
  insecure_skip_tls_verify = true
  iso_file                 = "${var.iso_file}"
  unmount_iso              = false

  os                       = "l26"
  cores                    = "4"
  memory                   = "8192"
  disks {
    disk_size         = "60G"
    storage_pool      = "local-lvm"
    storage_pool_type = "lvm"
    type              = "scsi"
  }
  scsi_controller      = "virtio-scsi-pci"

  network_adapters {
    bridge = "vmbr0"
    model = "virtio"
  }

  qemu_agent           = true
  template_name        = "ubuntu-template-yimeng"
  template_description = "Ubuntu 22.04 x86_64 template built with packer on ${local.date}"

  ssh_username         = "${var.ssh_username}"
  ssh_password         = "${var.ssh_password}"
  ssh_timeout          = "30m"


}

variable nodes {
}

build {
  name = "build"
  dynamic "source" {
    for_each = var.nodes
    labels = ["source.proxmox.ubuntu"]
    content {
      node = source.key
      name = source.value.image_name
      #vm_id = source.value.image_id
    }
}

  provisioner "shell" {
    inline = [
      "sudo truncate -s 0 /etc/machine-id",
      "sudo hostnamectl set-hostname $(openssl rand -hex 8)",
      "sudo env > ~/packer.env",
      "exit 0",
      ]
  }

}

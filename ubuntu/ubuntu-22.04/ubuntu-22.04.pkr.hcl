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
        "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"<enter><wait>",
        "initrd /casper/initrd<enter><wait>",
        "boot<enter>",
        "<enter><f10><wait>"]
}

locals {
    date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))
}

variable proxmox_username {
#    proxmox_username= vault("secrets/proxmox", "username")
    type  = string
    default = "username"
}

variable proxmox_password {
#    proxmox_password = vault("secrets/proxmox", "password")
    type   = string
    default = "password"
}

variable proxmox_url{
   # proxmox_url = vault("secrets/proxmox", "url")
   type   = string
   default = "https://xx.xx.xx.xx:8006/api2/json"
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
  username             = "${var.proxmox_username}"
  password             = "${var.proxmox_password}"
  proxmox_url          = "${var.proxmox_url}"
  # node                 = "pve211"

  boot_command =  "${local.boot_command}"
  boot_wait    = "3s"

  http_directory           = "cloud-init"
  http_interface           = "en1"
  insecure_skip_tls_verify = true
  iso_file                 = "${var.iso_file}"
  unmount_iso              = true

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
    bridge = "vmbr3"
    model = "virtio"
  }

  qemu_agent           = true
  template_name        = "ubuntu-template-yimeng"
  template_description = "Ubuntu 22.04 x86_64 template built with packer on ${local.date}"

  ssh_username         = "${var.ssh_username}"
  ssh_password         = "${var.ssh_password}"
  ssh_timeout          = "30m"
  
  # vm_id                = 241


}

variable nodes {
}

build {
  name = "proxmox"
  dynamic "source" {
    for_each = var.nodes
    labels = ["source.proxmox.ubuntu"]
    content {
      name = source.key
      node = source.value.proxmox_node
      vm_id = source.value.proxmox_vm_id
    }
}

  provisioner "shell" {
    inline = [
      "sudo truncate -s 0 /etc/machine-id",
      "sudo hostnamectl set-hostname $(openssl rand -hex 8)",
      "exit 0",
      ]
  }

}

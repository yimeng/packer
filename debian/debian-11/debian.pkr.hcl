locals {
        boot_command = ["<esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"]
}


locals {
    date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))
}

locals {
    proxmox_username = vault("secrets/office", "username")
    proxmox_password = vault("secrets/office", "password")
    proxmox_url = vault("secrets/office", "url")
    sensitive  = true
}

variable "ssh_username" {
  type    = string
  default = "packer"
}
# user-data identity password
variable "ssh_password" {
  type    = string
  default = "packer"
}

variable "iso_file" {
  type    = string
  default = "local:iso/debian-11.5.0-amd64-netinst.iso"
}



source "proxmox" "debian" {
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
  template_name        = "debian-template-yimeng"
  template_description = "debian 11 x86_64 template built with packer on ${local.date}"

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
    labels = ["source.proxmox.debian"]
    content {
      node = source.key
      name = source.value.image_name
      #vm_id = source.value.image_id
    }
}

  provisioner "shell" {
    inline = [
      #"sudo truncate -s 0 /etc/machine-id",
      #"hostname=$(openssl rand -hex 8) && sudo hostnamectl set-hostname $hostname && echo \"127.0.1.1 $hostname\" >> /etc/hosts",
      "sudo env > ~/packer.env",
      "exit 0",
      ]
  }

}

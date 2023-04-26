locals {
    date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))
}

locals {
    proxmox_username = vault("secrets/office", "username")
    proxmox_password = vault("secrets/office", "password")
    proxmox_url = vault("secrets/office", "url")
    sensitive  = true
}

source "proxmox" "ubuntu" {
  username             = "${local.proxmox_username}"
  password             = "${local.proxmox_password}"
  proxmox_url          = "${local.proxmox_url}"
}

variable nodes {
}

variable abc {
  default = 4
}

build {
  name = "build"
  dynamic "source" {
    for_each = var.nodes
    labels = ["source.proxmox.ubuntu"]
    content {
      node = source.key
      name = source.key

      os                       = source.value.os
      cores                    = source.value.cores
      memory                   = source.value.memory
      disks {
        disk_size         = source.value.disks.disk_size
        storage_pool      = source.value.disks.storage_pool
        storage_pool_type = source.value.disks.storage_pool_type
        type              = source.value.disks.type
      }
      scsi_controller      = source.value.scsi_controller

      network_adapters {
        bridge = source.value.network_adapters.bridge
        model = source.value.network_adapters.model
      }
      boot_command = source.value.boot_command
      boot_wait    = source.value.boot_wait

      ssh_username         = source.value.ssh_username
      ssh_password         = source.value.ssh_password
      ssh_timeout          = source.value.ssh_timeout

      template_name        = "ubuntu-template-yimeng"
      template_description = "source.value.template_description ${local.date}"

      iso_file             =  source.value.iso_file
      unmount_iso          =  source.value.unmount_iso

      http_directory           = source.value.http_directory
      http_interface           = source.value.http_interface
      insecure_skip_tls_verify = source.value.insecure_skip_tls_verify

      # name = source.value.image_name
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

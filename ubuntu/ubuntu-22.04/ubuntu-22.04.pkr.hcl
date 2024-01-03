locals {
    date = formatdate("YYYYMMDD-hhmm", timeadd(timestamp(), "8h"))
}

locals {
    proxmox_username = vault("secrets/proxmox", "username")
    proxmox_password = vault("secrets/proxmox", "password")
    proxmox_url = vault("secrets/proxmox", "url")
    sensitive  = true
}


variable nodes {
}

variable vm_template{

}

source "proxmox-iso" "ubuntu" {
  username                 = "${local.proxmox_username}"
  password                 = "${local.proxmox_password}"
  proxmox_url              = "${local.proxmox_url}"

  boot_command             = "${var.vm_template.init_env.boot_command}"
  boot_wait                = "${var.vm_template.init_env.boot_wait}"

  http_directory           = "${var.vm_template.init_env.http_directory}"
  http_interface           = "${var.vm_template.init_env.http_interface}"
  insecure_skip_tls_verify = "${var.vm_template.init_env.insecure_skip_tls_verify}"
  iso_file                 = "${var.vm_template.init_env.iso_file}"
  unmount_iso              = "${var.vm_template.init_env.unmount_iso}" 

  ssh_username         = "${var.vm_template.init_env.ssh_username}"
  ssh_password         = "${var.vm_template.init_env.ssh_password}"
  ssh_timeout          = "${var.vm_template.init_env.ssh_timeout}"

  os                       = "${var.vm_template.vm_env.os}"
  cores                    = "${var.vm_template.vm_env.cores}"
  memory                   = "${var.vm_template.vm_env.memory}"
  disks {
    disk_size         = "${var.vm_template.vm_env.disks.disk_size}"
    storage_pool      = "${var.vm_template.vm_env.disks.storage_pool}"
    type              = "${var.vm_template.vm_env.disks.type}"
  }
  scsi_controller     = "${var.vm_template.vm_env.scsi_controller}"

  network_adapters {
    bridge            = "${var.vm_template.vm_env.network_adapters.bridge}"
    model             = "${var.vm_template.vm_env.network_adapters.model}"
  }

  qemu_agent           = "${var.vm_template.vm_env.qemu_agent}"
  template_name        = "${var.vm_template.vm_env.template_name}"
  template_description = "${var.vm_template.vm_env.template_name} ${local.date}"

}



build {
  name = "build"
  dynamic "source" {
    for_each = var.nodes
    labels = ["source.proxmox-iso.ubuntu"]
    content {
      node = source.key
      name = source.value.image_name
      #vm_id = source.value.image_id
      vm_id = 899
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
packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# This file was autogenerated by the 'packer hcl2_upgrade' command. We
# recommend double checking that everything is correct before going forward. We
# also recommend treating this file as disposable. The HCL2 blocks in this
# file can be moved to other files. For example, the variable blocks could be
# moved to their own 'variables.pkr.hcl' file, etc. Those files need to be
# suffixed with '.pkr.hcl' to be visible to Packer. To use multiple files at
# once they also need to be in the same folder. 'packer inspect folder/'
# will describe to you what is in that folder.

# Avoid mixing go templating calls ( for example ```{{ upper(`string`) }}``` )
# and HCL2 calls (for example '${ var.string_value_example }' ). They won't be
# executed together and the outcome will be unknown.

# All generated input variables will be of 'string' type as this is how Packer JSON
# views them; you can change their type later on. Read the variables type
# constraints documentation
# https://www.packer.io/docs/templates/hcl_templates/variables#type-constraints for more info.
locals {
    proxmox_username= vault("secrets/proxmox", "username")
}

locals {
    proxmox_password = vault("secrets/proxmox", "password")
}

locals {
    proxmox_url = vault("secrets/proxmox", "url")
}

variable "node_name" {
  type    = string
  default = "homelab"
  sensitive   = true
}

# The "legacy_isotime" function has been provided for backwards compatability, but we recommend switching to the timestamp and formatdate functions.

# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors on a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "proxmox" "centos7" {
  username             = "${local.proxmox_username}"
  password             = "${local.proxmox_password}"
  proxmox_url          = "${local.proxmox_url}"

  ssh_username         = "root"
  ssh_password         = "packer"
  ssh_timeout          = "20m"

  boot_command = ["<up><tab> ip=dhcp inst.cmdline inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.j2<enter>"]
  boot_wait    = "2s"
  disks {
    disk_size         = "20G"
    storage_pool      = "local-lvm"
    storage_pool_type = "lvm"
    type              = "scsi"
  }
  http_directory           = "cloud-init"
  http_interface           = "ppp0"
  insecure_skip_tls_verify = true
  iso_file                 = "local:iso/CentOS-7-x86_64-Minimal-2009.iso"
  network_adapters {
    bridge = "vmbr0"
  }
  node                 = "${var.node_name}"

  qemu_agent           = true
  scsi_controller      = "virtio-scsi-pci"
  template_description = "CentOS 7<F4>, generated on ${legacy_isotime("2006-01-02T15:04:05Z")}"
  template_name        = "centos-template-test"
  unmount_iso          = true
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.proxmox.centos7"]

  provisioner "file" {
    destination = "/tmp/a.sh"
    source      = "a.sh"
  }

}

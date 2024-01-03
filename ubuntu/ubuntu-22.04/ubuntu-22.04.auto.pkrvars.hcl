nodes = {
  homelab = {
    image_name = "homelab"
    image_id = 285
  }
}

vm_template = {

  init_env = {
    boot_wait = "10s"
    http_directory = "cloud-init"
    http_interface = "ens18"
    insecure_skip_tls_verify = true
    iso_file                 = "local:iso/jammy-live-server-amd64.iso"
    unmount_iso              = false
    ssh_username = "ubuntu"
    ssh_password = "ubuntu"
    ssh_timeout  = "30m"

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
      "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;live-updates=off;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"<enter><wait>",
      "initrd /casper/initrd<enter><wait>",
      "boot<enter>",
      "<enter><f10><wait>"]

  }

  vm_env = {
    os                       = "l26"
    cores                    = "4"
    memory                   = "8192"

    disks = {
      disk_size         = "60G"
      storage_pool      = "local-lvm"
      type              = "scsi"
    }

    scsi_controller      = "virtio-scsi-pci"
    network_adapters = {
      bridge = "vmbr0"
      model = "virtio"
    }

    
    qemu_agent           = true
    template_name        = "ubuntu-template-yimeng"
    template_description = "Ubuntu 22.04 x86_64 template built with packer on "
  }  

}



#  pve212 = {
#    proxmox_node =  "pve212"
#    proxmox_vm_id = 296
#  }
#  pve213= {
#    image_name = "pve213"
#    image_id = 297
#  }



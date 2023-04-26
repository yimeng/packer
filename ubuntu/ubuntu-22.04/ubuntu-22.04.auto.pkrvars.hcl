nodes = {
  pve211 = {
    os = "l26"
    # cores                    = "4"
    memory                   = "8192"
    disks = {
        disk_size         = "60G"
        storage_pool      = "local-lvm"
        storage_pool_type = "lvm"
        type              = "scsi"
    }
    scsi_controller      = "virtio-scsi-pci"

    network_adapters = {
        bridge = "vmbr3"
        model = "virtio"
    }

    http_directory           = "cloud-init"
    http_interface           = "en1"
    insecure_skip_tls_verify = true

    ssh_username = "ubuntu"
    ssh_password = "ubuntu"
    ssh_timeout = "30m"
    qemu_agent           = true

    iso_file                 = "local:iso/ubuntu-22.04-live-server-amd64.iso"
    unmount_iso              = false

    template_name = "ubuntu-template-yimeng"
    template_description = "Ubuntu 22.04 x86_64 template built with packer on"

    boot_wait    = "3s"
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
#  pve212 = {
#    proxmox_node =  "pve212"
#    proxmox_vm_id = 296
#  }
#  pve213= {
#    image_name = "pve213"
#    image_id = 297
#  }
}


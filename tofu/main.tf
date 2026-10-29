provider "proxmox" {
  insecure = true
}

resource "proxmox_virtual_environment_vm" "k3s" {
  for_each = var.vms

  node_name = each.value.node
  vm_id     = each.value.vm_id
  name      = each.value.name
  started   = true
  on_boot   = true

  clone {
    vm_id = each.value.template_id
  }

  cpu {
    type  = "host"
    cores = 4
    numa  = true
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = each.value.disk_size
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.86.1"
      }
    }

    user_account {
      username = "debian"
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = ["192.168.86.1"]
    }
  }
}
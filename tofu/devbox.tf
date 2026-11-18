# The devbox VM (ADR-0033, playbook 02c). A separate resource from the k3s
# map so k3s/install.sh and nodes.conf never see it.
resource "proxmox_virtual_environment_vm" "devbox" {
  node_name = var.devbox.node
  vm_id     = var.devbox.vm_id
  name      = var.devbox.name
  started   = true
  on_boot   = true

  clone {
    vm_id = var.devbox.template_id
  }

  cpu {
    type  = "host"
    cores = var.devbox.cores
    numa  = true
  }

  memory {
    dedicated = var.devbox.memory
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.devbox.datastore
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.devbox.disk_size
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
        address = "${var.devbox.ip}/24"
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

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true

  api_token = var.proxmox_api_token
}

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Proxmox VE API token"
  type        = string
  sensitive   = true
}

resource "proxmox_virtual_environment_vm" "k3s" {
  node_name = var.proxmox_node
  vm_id     = var.vm_id
  name      = var.vm_name
  started   = true
  on_boot   = true

  clone {
    vm_id = var.template_id
  }

  cpu {
    type  = "host"
    cores = 4
    numa  = true
  }

  memory {
    dedicated = 5120
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 80
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
        address = var.vm_ip
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = "debian"
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = [var.vm_dns]
    }
  }
}
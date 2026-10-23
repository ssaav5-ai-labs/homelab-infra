variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve01"
}

variable "vm_id" {
  description = "VM ID"
  type        = number
  default     = 101
}

variable "vm_name" {
  description = "VM name"
  type        = string
  default     = "k3s-01"
}

variable "template_id" {
  description = "Cloud-init template VM ID to clone"
  type        = number
  default     = 9000
}

variable "vm_ip" {
  description = "Static IP for the VM (CIDR notation)"
  type        = string
}

variable "vm_gateway" {
  description = "Default gateway"
  type        = string
  default     = "192.168.86.1"
}

variable "vm_dns" {
  description = "DNS server"
  type        = string
  default     = "192.168.86.1"
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}
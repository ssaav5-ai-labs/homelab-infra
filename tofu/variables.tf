variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    node        = string
    vm_id       = number
    name        = string
    template_id = number
    ip          = string
    disk_size   = number
    memory      = number
  }))
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}
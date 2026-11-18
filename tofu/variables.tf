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
    cores       = optional(number, 4)
    datastore   = optional(string, "local-lvm")
  }))
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}

variable "devbox" {
  description = "The devbox VM that runs the dev containers (ADR-0033)"
  type = object({
    node        = optional(string, "pve03")
    vm_id       = optional(number, 110)
    name        = optional(string, "devbox")
    template_id = optional(number, 9003)
    ip          = optional(string, "192.168.86.214")
    disk_size   = optional(number, 120)
    memory      = optional(number, 8192)
    cores       = optional(number, 4)
    datastore   = optional(string, "nvme-data")
  })
  default = {}
}

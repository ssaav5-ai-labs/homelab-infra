output "vm_ips" {
  description = "Map of VM name to IP address"
  value       = { for k, v in var.vms : k => v.ip }
}
output "container" {
  description = "Container data"

  value = {
    name = incus_instance.vm.name
    ip   = var.ipv4_address
  }
}

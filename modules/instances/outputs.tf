output "container" {
  description = "Container data"
  value = {
    name = incus_instance.vm.name

    ip = one([
      for d in incus_instance.vm.device :
      d.properties["ipv4.address"]
      if d.name == "eth0"
    ])
  }
}

output "containers" {
  description = "Container data"
  value = {
    for name, inst in module.incus_instances :
    name => inst.container
  }
}

output "reminder" {
  value = "Container is up! Please wait ~30 seconds for the setup script to finish before SSHing."
}

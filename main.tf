locals {
  // check with command below:
  // incus config show <container name> | grep "user\."
  project_metadata = {
    "user.project_name" = basename(abspath(path.cwd))
    "user.project_path" = abspath(path.cwd)
    "user.managed_by"   = "opentofu"
    // 'timestamp' will always change when run 'tofu apply'
    // run command below instead, to check container creation date
    // incus exec <container name> -- cat /var/log/lab-setup.log
    // "user.created_at"   = timestamp()
  }
}

module "incus_instances" {
  source = "./modules/instances"

  // 'for_each' will loop through the 'incus_instances' variables map
  for_each      = var.incus_instances
  instance_name = each.key

  // check each variables description at 'variables.tf' file.
  // remove comments from variables below because when run 'tofu fmt', it look too messy
  ipv4_address = each.value.ip
  cpu_limit    = each.value.cpu
  memory_limit = each.value.memory
  nesting      = each.value.nesting
  bind_mounts  = each.value.bind_mounts
  extra_config = merge(local.project_metadata, each.value.extra_config)
  username     = var.username
  ssh_key      = var.ssh_public_key
  timezone     = var.timezone
  image        = var.incus_image
  storage_pool = var.incus_storage_pool
  network_name = var.incus_network
  nic_type     = var.incus_nic_type
}

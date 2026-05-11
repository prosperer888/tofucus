module "incus_instances" {
  source = "./modules/instances"

  // 'for_each' will loop through the 'incus_instances' variables map
  for_each      = var.incus_instances
  instance_name = each.key

  ipv4_address  = each.value.ip
  cpu_limit     = each.value.cpu
  memory_limit  = each.value.memory
  // variable for enable nested virtualization inside incus containers
  nesting       = each.value.nesting
  // bind mount host directory inside container
  // https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container
  bind_mounts   = each.value.bind_mounts

  username      = var.username
  ssh_key       = var.ssh_public_key
  timezone      = var.timezone

  image         = var.incus_image
  storage_pool  = var.incus_storage_pool
  network_name  = var.incus_network
  nic_type      = var.incus_nic_type
}

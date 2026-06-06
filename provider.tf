provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true
  default_remote               = var.incus_remote_name

  remote {
    name    = var.incus_remote_name
    address = var.incus_remote_address
    token   = var.incus_remote_token
  }

  # if running tofu from system where incus is not installed
  # https://search.opentofu.org/provider/lxc/incus/latest#specifying-multiple-remotes
}

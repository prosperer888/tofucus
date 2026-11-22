variable "instance_name" { type = string }
variable "image" { type = string }
variable "storage_pool" { type = string }
variable "network_name" { type = string }
variable "ssh_key" { type = string }
variable "username" { type = string }
variable "cpu_limit" { type = number }
variable "memory_limit" { type = string }
variable "timezone" { type = string }
variable "nic_type" { type = string }
variable "bind_mounts" {
  description = "List of host directories to bind mount into the container"
  type = list(object({
    host_path  = string                // absolute path on the host
    mount_path = string                // path inside the container
    readonly   = optional(bool, false) // Controls whether to make the mount read-only
    // Sets up a shifting overlay to translate the source UID/GID to match the instance (only for containers)
    // https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container
    shift = optional(bool, false)
  }))
  default = []
}

variable "nesting" {
  description = "Enable nesting to run nested virtualization inside container."
  type        = bool
  default     = false
}

variable "extra_config" {
  description = "Extra incus configuration key/value pairs to merge into the main container's config."
  type        = map(string)
  default     = {}
}

variable "ipv4_address" {
  description = "Static IPv4 address for the instance, or null when using DHCP without an Incus reservation"
  type        = string
  default     = null
}

variable "dhcp_enabled" {
  description = "Whether containers should obtain their IP addresses through DHCP"
  type        = bool
  default     = true
}

variable "ipv4_gateway" {
  description = "IPv4 gateway for unmanaged bridge networking"
  type        = string
  default     = null
}

variable "dns_nameservers" {
  description = "DNS servers for container network configuration"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

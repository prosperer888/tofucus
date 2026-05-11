variable "instance_name" { type = string }
variable "ipv4_address"  { type = string }
variable "image"         { type = string }
variable "storage_pool"  { type = string }
variable "network_name"  { type = string }
variable "ssh_key"       { type = string }
variable "username"      { type = string }
variable "cpu_limit"     { type = number }
variable "memory_limit"  { type = string }
variable "timezone"      { type = string }
variable "nic_type"      { type = string }
variable "bind_mounts" {
  description = "List of host directories to bind mount into the container"
  type = list(object({
    host_path  = string // absolute path on the host
    mount_path = string // path inside the container
    readonly   = optional(bool, false) // Controls whether to make the mount read-only
    // Sets up a shifting overlay to translate the source UID/GID to match the instance (only for containers)
    // https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container
    shift      = optional(bool, false)
  }))
  default = []
}
variable "nesting" {
  description = "Enable nesting to run nested virtualization inside container."
  type        = bool
  default     = false
}

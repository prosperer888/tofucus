// variable "incus_remote" {
//   type        = string
//   default     = "local"
//   description = "The incus remote to use. 'local' for the local Unix socket, or the name of a remote configured via 'incus remote add'."
// }

variable "incus_instances" {
  type = map(object({
    ip      = string
    cpu     = number
    memory  = string
    nesting = optional(bool, false)
    bind_mounts  = optional(list(object({
      host_path  = string
      mount_path = string
      readonly   = optional(bool, false)
      shift      = optional(bool, false) # https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container
    })), [])
    extra_config = optional(map(string), {})
  }))
  description = "Map of container names to their configuration. Each entry requires a static IPv4 address (e.g. '10.150.19.50'), CPU cores as number (e.g. 2), and memory limit (e.g. '2GiB')."

  // host path validation
  validation {
    condition = alltrue([
      for inst in var.incus_instances :
      alltrue([
        for d in inst.bind_mounts :
        can(regex("^/", d.host_path))
      ])
    ])
    error_message = "host_path must be an absolute path (start with /)"
  }

  // CPU validation
  validation {
    condition = alltrue([
      for inst in var.incus_instances :
      inst.cpu > 0
    ])
    error_message = "CPU must be greater than 0."
  }

  // Memory validation
  validation {
    condition = alltrue([
      for inst in var.incus_instances :
      can(regex("^[0-9]+(MiB|GiB)$", inst.memory))
    ])
    error_message = "Memory must be like 512MiB or 2GiB."
  }

  // IP validation
  validation {
    condition = alltrue([
      for inst in var.incus_instances :
      can(cidrhost("${inst.ip}/32", 0))
    ])
    error_message = "IP must be a valid IPv4 address."
  }

  // Duplicate ip validation
  validation {
    condition = length(distinct([
      for inst in var.incus_instances : inst.ip
    ])) == length(var.incus_instances)

    error_message = "Duplicate IP addresses are not allowed."
  }
}

variable "incus_image" {
  type        = string
  description = "Incus image name. Must include cloud-init support (usually images with '/cloud' in the name, e.g. 'debian/12/cloud', 'ubuntu/22.04/cloud')."

  validation {
    condition     = can(regex("/cloud$", var.incus_image))
    error_message = "Image must be a cloud image (end with /cloud)."
  }
}

variable "incus_storage_pool" {
  type        = string
  description = "Name of the incus storage pool to use for the container's root disk. Default pool is often 'default'."
}

variable "incus_network" {
  type        = string
  description = "Name of the incus managed network bridge (e.g. 'incusbr0'). The container's NIC will attach to this network."
}

variable "incus_nic_type" {
  type        = string
  default     = "bridged"
  description = "Type of network interface. Use 'bridged' for attaching to an existing incus bridge, or 'macvlan' for direct physical network access. Defaults to 'bridged'."

  validation {
    condition     = contains(["bridged", "macvlan", "ovn"], var.incus_nic_type)
    error_message = "NIC type must be one of: bridged, macvlan, ovn."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "The content of the SSH public key file (e.g. contents of $HOME/.ssh/id_ed25519.pub). This key will be added to the containers non root user."
}

variable "username" {
  type        = string
  default     = "incus"
  description = "Non root username created inside the container. This user will have passwordless sudo access."

  validation {
    condition     = length(var.username) > 0
    error_message = "Username must not be empty."
  }
}

variable "timezone" {
  type        = string
  default     = "UTC"
  description = "System timezone for the container (e.g. 'Asia/Kuala_Lumpur', 'Europe/Rome'). Defaults to 'UTC'."
}

variable "incus_remote_name" {
  type        = string
  default     = "local"
  description = "The default remote to use (default are 'local')"
}

variable "incus_remote_address" {
  type        = string
  default     = "unix://"
  sensitive   = false
  description = "Address of the incus remote (e.g., 'unix://' or 'https://192.168.1.100:8443'. Default are 'unix://')"
}

variable "incus_remote_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "Trust token for the incus remote (required for HTTPS remotes (if not using 'unix://' socket))"
}

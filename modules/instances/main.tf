locals {
  # variables for enable nested virtualization inside incus containers
  nesting_config = var.nesting ? {
    "security.nesting"                     = "true"
    "security.syscalls.intercept.mknod"    = "true"
    "security.syscalls.intercept.setxattr" = "true"
  } : {}

  // base/default configuration
  base_config = {
    "boot.autostart" = "true"
    "limits.cpu"     = tostring(var.cpu_limit)
    "limits.memory"  = tostring(var.memory_limit)
    // cloud-init
    "cloud-init.user-data" = templatefile("${path.module}/template/cloud-init.yaml.tftpl", {
      // below are variables that can be pass to cloud-init template file
      username = var.username
      ssh_key  = var.ssh_key
      timezone = var.timezone
      // if 'var.nesting' is 'true', the cloud-init will install 'fuse-overlayfs'
      // useful for docker inside incus. (not yet try if using btrfs or zfs require it or not)
      nesting  = var.nesting
    })
  }
}

resource "incus_instance" "vm" {
  name      = var.instance_name
  image     = "images:${var.image}"
  type      = "container"
  running   = true

  // merge configs (order)
  config = merge(
    local.base_config,
    local.nesting_config,
    var.extra_config
  )

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      nictype  = var.nic_type
      parent   = var.network_name
      // sets static ip
      "ipv4.address" = var.ipv4_address
    }
  }

  // https://linuxcontainers.org/incus/docs/main/reference/devices_disk/#type-disk
  dynamic "device" {
    for_each = var.bind_mounts
    content {
      name = "bind-${substr(md5(device.value.host_path), 0, 8)}"
      type = "disk"
      properties = {
        source   = device.value.host_path
        path     = device.value.mount_path
        // use ternary to set boolean value into ("string")
        // condition ? true_value : false_value
        readonly = device.value.readonly ? "true" : "false"
        shift    = device.value.shift ? "true" : "false"
      }
    }
  }
}

# OpenTofu Module: Incus Containers

`tofucus` – OpenTofu module for managing Incus containers.

An OpenTofu configuration that deploys [Incus](https://linuxcontainers.org/incus/) containers with
**DHCP or static IPv4 addresses, resource limits, cloud-init provisioning, and optional bind mounts
(host directories)**.

This module uses the OpenTofu provider from
[lxc/incus](https://search.opentofu.org/provider/lxc/incus/latest). We can view the provider's
resources and data sources in its
[documentation](https://search.opentofu.org/provider/lxc/incus/latest).

> [!WARNING]
>
> - Only works with Incus images that include cloud-init (usually images with `/cloud` in the name).
> - This module supports **containers only** (not Incus virtual machines).

<!-- TABLE OF CONTENTS -->

## Table Of Contents

<details>
  <summary>Click to expand</summary>

<!-- toc -->

- [Description](#description)
- [Supported Platforms (container images)](#supported-platforms-container-images)
- [Requirements](#requirements)
  - [OpenTofu](#opentofu)
  - [Incus](#incus)
- [Project Structure](#project-structure)
- [Variables](#variables)
  - [Container Configuration](#container-configuration)
  - [Networking Configuration](#networking-configuration)
    - [1. Incus-managed bridge with DHCP](#1-incus-managed-bridge-with-dhcp)
    - [2. Unmanaged Linux bridge with DHCP](#2-unmanaged-linux-bridge-with-dhcp)
    - [3. Unmanaged Linux bridge with a static IP](#3-unmanaged-linux-bridge-with-a-static-ip)
  - [Bind Mounts](#bind-mounts)
  - [Example `terraform.tfvars`](#example-terraformtfvars)
  - [Running Docker Inside an Incus Container](#running-docker-inside-an-incus-container)
- [Usage](#usage)
  - [Adding or Removing Containers](#adding-or-removing-containers)
  - [Attaching Shared Directories to Containers](#attaching-shared-directories-to-containers)
  - [Quick Start](#quick-start)
  - [Outputs](#outputs)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
  - [Container Created but Cannot SSH](#container-created-but-cannot-ssh)
  - [Container Does Not Get an IP Address](#container-does-not-get-an-ip-address)
  - [Bind Mount Permission Denied](#bind-mount-permission-denied)
- [TODO](#todo)
- [License](#license)

<!-- tocstop -->

</details>

<!-- DESCRIPTION -->

## Description

This OpenTofu configuration will:

- Create multiple containers using a simple map variable.
- Support **DHCP and static IPv4 addresses**.
- Support both **Incus-managed bridges** (e.g. `incusbr0`) and **unmanaged Linux bridges** (e.g.
  `br0`).
- Set **CPU and memory** limits per container.
- Optionally bind mount host directories into containers.
- Optionally add extra configurations from
  [Incus instance options](https://linuxcontainers.org/incus/docs/main/reference/instance_options/).
- Automatically:
  - Create a non-root user with passwordless sudo.
  - Add an SSH public key.
  - Install common packages (`curl`, `git`, `openssh-server`, `python3`).
  - Enable and start SSH.
  - Support Debian/Ubuntu, Red Hat/Fedora, and Arch Linux images that include cloud-init.

<!-- SUPPORTED PLATFORMS -->

## Supported Platforms (container images)

- Debian/Ubuntu
- Red Hat/Fedora family
- Arch Linux

Use Incus cloud images (images ending with `/cloud`). We can search available images with:

```shell
incus image list images:
```

<!-- REQUIREMENTS -->

## Requirements

### OpenTofu

- OpenTofu >= 1.9.1
- Provider [`lxc/incus`](https://search.opentofu.org/provider/lxc/incus/latest) >= 0.3.1
  (automatically downloaded when running `tofu init`).

### Incus

- Incus installed and initialised (`incus admin init`).
- A network bridge, such as `incusbr0` or an existing Linux bridge such as `br0`.
- A storage pool (default: `default`).
- User must have permission to access the Incus socket (usually a member of the `incus-admin`
  group).
- Incus cloud images available (example: `debian/12/cloud`).

We can check our available networks and storage pools with:

```shell
incus network list
incus storage list
```

<!-- PROJECT STRUCTURE -->

## Project Structure

```shell
.
├── main.tf
├── modules
│   └── instances
│       ├── main.tf
│       ├── outputs.tf
│       ├── template
│       │   ├── cloud-init.yaml.tftpl
│       │   └── network-config.yaml.tftpl
│       ├── variables.tf
│       └── versions.tf
├── outputs.tf
├── provider.tf
├── terraform.tfvars
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

<!-- VARIABLES -->

## Variables

Variables are defined in `variables.tf` and can be overridden in `terraform.tfvars`.

| Variable             | Type               | Required | Description                                                                    |
| -------------------- | ------------------ | :------: | ------------------------------------------------------------------------------ |
| `incus_instances`    | `map(object(...))` |   Yes    | Container definitions, including IP, CPU, memory, and optional settings.       |
| `incus_image`        | `string`           |   Yes    | Incus image name (e.g. `debian/12/cloud`).                                     |
| `incus_storage_pool` | `string`           |   Yes    | Incus storage pool name (e.g. `default`).                                      |
| `incus_network`      | `string`           |   Yes    | Network or bridge name (e.g. `incusbr0` or `br0`).                             |
| `incus_nic_type`     | `string`           |    No    | Network interface type. Defaults to `bridged`.                                 |
| `incus_dhcp_enabled` | `bool`             |    No    | Whether containers obtain their IP addresses through DHCP. Defaults to `true`. |
| `incus_gateway`      | `string`           | Depends  | IPv4 gateway used for static network configuration.                            |
| `incus_dns_servers`  | `list(string)`     |    No    | DNS servers used for static network configuration.                             |
| `ssh_public_key`     | `string`           |   Yes    | Content of our SSH public key.                                                 |
| `username`           | `string`           |    No    | Non-root username inside containers (default: `incus`).                        |
| `timezone`           | `string`           |    No    | Container timezone (default: `UTC`).                                           |

### Container Configuration

The `incus_instances` variable uses a map of objects.

```hcl
incus_instances = {
  "<name>" = {
    ip      = optional(string, null)
    cpu     = number
    memory  = string

    # Optional
    nesting = bool

    bind_mounts = [
      {
        host_path  = string
        mount_path = string
        readonly   = bool
        shift      = bool
      }
    ]

    extra_config = map(string)
  }
}
```

Required container configuration:

- `ip` - Static IPv4 address for the container. Use `null` when we want to used DHCP.
- `cpu` - Number of CPU cores allocated to the container (e.g. `2`).
- `memory` - Memory limit with unit (e.g. `2GiB` or `512MiB`).

Optional container configuration:

- `nesting` - Enable nested virtualization inside the container (default: `false`).
- `bind_mounts` - List of host directories to mount inside the container (default: `[]`).
- `extra_config` - Additional Incus instance configurations from
  [Incus instance options](https://linuxcontainers.org/incus/docs/main/reference/instance_options/)
  (default: `{}`).

The `ip` field is optional and defaults to `null`. We can either set it to `null` or leave it out
when using DHCP without a static reservation.

For example:

```hcl
incus_instances = {
  "web" = {
    ip     = "10.150.19.50"
    cpu    = 2
    memory = "2GiB"
  }

  "worker" = {
    ip     = null
    cpu    = 1
    memory = "1GiB"
  }
}
```

> [!NOTE]
>
> The `memory` field only accepts values in `MiB` or `GiB` (e.g. `512MiB`, `2GiB`). Other units such
> as `MB`, `GB`, or `KiB` are not allowed by this module.

### Networking Configuration

This module supports both Incus-managed bridges and unmanaged Linux bridges.

The networking behavior depends on our bridge and DHCP settings.

| Network type                           | DHCP enabled | IP value  | Result                                             |
| -------------------------------------- | ------------ | --------- | -------------------------------------------------- |
| Incus-managed bridge (e.g. `incusbr0`) | `true`       | `null`    | Incus DHCP assigns an IP address.                  |
| Incus-managed bridge (e.g. `incusbr0`) | `true`       | Static IP | Incus uses the IP as a DHCP reservation.           |
| Unmanaged Linux bridge (e.g. `br0`)    | `true`       | `null`    | External DHCP server/router assigns an IP address. |
| Unmanaged Linux bridge (e.g. `br0`)    | `false`      | Static IP | Cloud-init configures the static IP address.       |

#### 1. Incus-managed bridge with DHCP

For an Incus-managed bridge such as `incusbr0`, Incus provides DHCP.

Set:

```hcl
incus_network      = "incusbr0"
incus_dhcp_enabled = true
incus_gateway      = null
```

Example container configuration:

```hcl
incus_instances = {
  "web" = {
    ip     = null
    cpu    = 2
    memory = "2GiB"
  }
}
```

Incus DHCP assigns an IP address to the container.

We can also provide an IP address if we want Incus to reserve that address for the container:

```hcl
incus_instances = {
  "web" = {
    ip     = "10.150.19.50"
    cpu    = 2
    memory = "2GiB"
  }
}
```

In this case, Incus DHCP assigns the reserved IP address to the container.

#### 2. Unmanaged Linux bridge with DHCP

We can also use an existing Linux bridge, such as `br0`, connected to our physical network.

Set:

```hcl
incus_network      = "br0"
incus_dhcp_enabled = true
incus_gateway      = null
```

Example container configuration:

```hcl
incus_instances = {
  "web" = {
    ip     = null
    cpu    = 2
    memory = "2GiB"
  }
}
```

The external DHCP server (usually our router) assigns an IP address to the container.

Because `br0` is an unmanaged bridge, Incus does not manage DHCP reservations for it. Leave
`ip = null` when using DHCP this way.

#### 3. Unmanaged Linux bridge with a static IP

We can configure a static IP address when using an unmanaged Linux bridge.

Set:

```hcl
incus_network      = "br0"
incus_dhcp_enabled = false
incus_gateway      = "192.168.0.1"
incus_dns_servers  = ["1.1.1.1", "8.8.8.8"]
```

Example container configuration:

```hcl
incus_instances = {
  "web" = {
    ip     = "192.168.0.150"
    cpu    = 2
    memory = "2GiB"
  }

  "db" = {
    ip     = "192.168.0.151"
    cpu    = 1
    memory = "1GiB"
  }
}
```

Cloud-init configures the static IP address, gateway, and DNS servers inside each container.

> [!IMPORTANT]
>
> - Make sure static IP addresses belong to the correct subnet.
> - Make sure the addresses are not already in use.
> - Avoid assigning addresses inside our router's DHCP range unless we already reserved them.
> - When using static IP configuration, provide a valid gateway.
> - When using DHCP, the gateway and DNS information are normally provided by the DHCP server.

### Bind Mounts

Optionally mount host directories into containers.

See the
[Incus bind mount documentation](https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container).

Available options:

- `host_path` - Existing directory on the host (use an absolute path, e.g. `/home/user/data`).
- `mount_path` - Destination path inside the container (e.g. `/media`).
- `readonly` - Set to `true` for read-only access (default: `false`).
- `shift` - Enable idmapped mounts to help fix permission issues (default: `false`).

> [!NOTE]
>
> The `host_path` must already exist on the host system. OpenTofu/Incus will not create the
> directory automatically.

<!-- -->

> [!WARNING]
>
> Bind mounts expose host directories directly to containers:
>
> - Deleting files inside the container will also delete them on the host.
> - Incorrect permissions may break applications.
> - Use `shift = true` when needed to avoid permission issues.
> - Always double-check paths before running `tofu apply`.

### Example `terraform.tfvars`

```hcl
# Container definitions.
#
# ip       - Static IPv4 address, or null when using DHCP without a reservation.
# cpu      - Number of CPU cores allocated to the container.
# memory   - Memory limit with unit (MiB or GiB).
# nesting  - Optional. Enable nested virtualization inside the container.
# bind_mounts - Optional. List of host directories to bind mount.
# extra_config - Optional. Additional Incus instance configuration.

incus_instances = {
  "media" = {
    ip      = "10.150.19.50"
    cpu     = 2
    memory  = "2GiB"
    nesting = true

    bind_mounts = [
      {
        host_path  = "/mnt/media"
        mount_path = "/media"
        readonly   = false
        shift      = true
      }
    ]
  }

  "db" = {
    ip     = "10.150.19.51"
    cpu    = 1
    memory = "1GiB"

    extra_config = {
      "boot.autostart.priority" = "100"
    }
  }

  # DHCP without a static reservation.
  "worker" = {
    ip     = null
    cpu    = 1
    memory = "1GiB"
  }
}

# Incus configuration.
incus_image        = "debian/12/cloud"
incus_network      = "incusbr0"
incus_storage_pool = "default"
incus_nic_type     = "bridged"

# Networking configuration.
incus_dhcp_enabled = true
incus_gateway      = null
incus_dns_servers  = ["1.1.1.1", "8.8.8.8"]

# User configuration.
ssh_public_key = "ssh-ed25519 AAAAC3... user@host"
username       = "incus"
timezone       = "Asia/Kuala_Lumpur"
```

### Running Docker Inside an Incus Container

> [!NOTE]
>
> If we want to run Docker containers inside an Incus container, enable nesting with
> `nesting = true`.
>
> We may also need to configure Docker to use the `fuse-overlayfs` storage driver. This setup has
> not yet been tested with `btrfs` or `zfs`.

Inside the container, create or edit `/etc/docker/daemon.json` after installing Docker:

```shell
sudo vi /etc/docker/daemon.json
```

Insert the following JSON:

```json
{
  "storage-driver": "fuse-overlayfs"
}
```

Then restart Docker:

```shell
sudo systemctl restart docker
```

This can help avoid the `invalid argument` error with the default overlayfs storage driver on an
already-nested filesystem.

<!-- USAGE -->

## Usage

- Clone the project.

  Copy the [terraform.tfvars.example](terraform.tfvars.example) variables into `terraform.tfvars`,
  then update our SSH key and desired containers.

  ```shell
  cd tofucus
  cp terraform.tfvars.example terraform.tfvars
  ```

- Initialize OpenTofu.

  ```shell
  tofu init
  ```

- Review the plan.

  ```shell
  tofu plan
  ```

- Apply the configuration.

  ```shell
  tofu apply -auto-approve
  ```

  Or provide our SSH public key directly:

  ```shell
  tofu apply -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" -auto-approve
  ```

- Wait for cloud-init to finish (approximately 30 seconds).

- SSH into a container.

  ```shell
  ssh incus@10.150.19.50
  ```

- Destroy everything.

  ```shell
  tofu destroy -auto-approve
  ```

### Adding or Removing Containers

To add a container, append a new entry to the `incus_instances` map in `terraform.tfvars`.

To remove a container, delete its entry from the map.

```hcl
incus_instances = {
  "web" = {
    ip     = "10.150.19.50"
    cpu    = 2
    memory = "2GiB"
  }

  # Removed container:
  # "db" = {
  #   ip     = "10.150.19.51"
  #   cpu    = 1
  #   memory = "1GiB"
  # }

  # Added container:
  "cache" = {
    ip     = "10.150.19.52"
    cpu    = 1
    memory = "1GiB"
  }
}
```

### Attaching Shared Directories to Containers

Common use cases:

- Share media between containers (e.g. Jellyfin and Sonarr).
  - Mount the same host directory (e.g. `/mnt/media`) into multiple containers.
- Persist important data.
  - Store configurations and repositories on the host using bind mounts.

Example:

```hcl
incus_instances = {
  "jellyfin" = {
    ip      = "10.150.19.50"
    cpu     = 2
    memory  = "2GiB"
    nesting = true

    bind_mounts = [
      {
        host_path  = "/mnt/media"
        mount_path = "/media"
        shift      = true
      }
    ]

    extra_config = {
      "boot.autostart.priority" = "100"
    }
  }

  "sonarr" = {
    ip      = "10.150.19.51"
    cpu     = 1
    memory  = "1GiB"
    nesting = true

    bind_mounts = [
      {
        host_path  = "/mnt/media"
        mount_path = "/media"
        shift      = true
      }
    ]
  }
}
```

Then run `tofu plan` to review the changes, followed by `tofu apply`.

> [!NOTE]
>
> Removing a container will destroy its filesystem. Any data stored inside the container will be
> lost.
>
> Bind mount directories remain on the host system. OpenTofu/Incus will not destroy the host
> directories when the containers are destroyed.

<!-- QUICK START -->

### Quick Start

```shell
git clone <repo>
cd tofucus
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" -auto-approve
```

<!-- OUTPUTS -->

### Outputs

Example output after applying the configuration:

```hcl
containers = {
  "web" = {
    "ip"   = "10.150.19.50"
    "name" = "web"
  }

  "db" = {
    "ip"   = "10.150.19.51"
    "name" = "db"
  }

  "worker" = {
    "ip"   = null
    "name" = "worker"
  }
}

reminder = "Container is up! Please wait ~30 seconds for the setup script to finish before SSHing."
```

**Note:** The output shows the IP address configured in `terraform.tfvars`. When `ip = null`, the
output will also be `null`, even if the container receives an IP address from DHCP.

To see the actual IP address assigned to a container, use:

```shell
incus list
```

SSH into a container using its actual IP address:

```shell
ssh incus@10.150.19.50
```

<!-- HOW IT WORKS -->

## How It Works

- The root [main.tf](main.tf) calls the instances module once for each entry in
  `var.incus_instances`.
- The module `modules/instances/main.tf`:
  - Creates an `incus_instance` resource with the specified **name, image, CPU, and memory**.
  - Attaches a root disk device using the selected storage pool.
  - Attaches an `eth0` network device to the selected network.
  - Applies cloud-init user-data and network configuration templates.

- Network configuration:
  - Uses DHCP when `incus_dhcp_enabled = true`.
  - Uses static IP configuration when `incus_dhcp_enabled = false`.
  - Adds an Incus DHCP reservation when using a managed bridge with DHCP and a static IP is
    provided.
  - Leaves IP assignment to the external DHCP server when using an unmanaged bridge with DHCP and
    `ip = null`.

- **Optionally** attaches additional disk devices for bind mounts:
  - Maps host directories into the container filesystem.
  - Useful for sharing media, repositories, or configurations.

- **Optionally** adds extra configurations from
  [Incus instance options](https://linuxcontainers.org/incus/docs/main/reference/instance_options/).
  - Useful when the default configurations used by this module are not enough.

- **Optionally** enables nesting capabilities for Incus containers.
  - Useful when running Docker or another Incus instance inside a container.

- Cloud-init on the container:
  - Creates the user and adds the SSH key.
  - Writes a helper script (`/usr/local/bin/setup-lab.sh`) that detects the distribution and
    installs packages using `apt`, `dnf`, or `pacman`.
  - Runs the script using `runcmd`.

- The module output shows container names and their configured IP addresses.

<!-- TROUBLESHOOT -->

## Troubleshooting

### Container Created but Cannot SSH

- Wait approximately 30 seconds. Cloud-init may still be running.
- Check cloud-init status:

  ```shell
  incus exec <container> -- cloud-init status
  ```

- Check whether the SSH service is running:

  ```shell
  incus exec <container> -- systemctl status ssh
  ```

  Or:

  ```shell
  incus exec <container> -- systemctl status sshd
  ```

- Check the setup logs:

  ```shell
  incus exec <container> -- cat /var/log/lab-setup.log
  ```

- Check the container's IP address:

  ```shell
  incus list
  ```

### Container Does Not Get an IP Address

- Check that the container is connected to the correct network:

  ```shell
  incus config show <container> --expanded
  ```

- If using an Incus-managed bridge, check the network configuration:

  ```shell
  incus network show incusbr0
  ```

- If using an unmanaged Linux bridge such as `br0`, make sure the external DHCP server (usually our
  router) is working and has available addresses.
- If using static IP configuration:
  - Make sure `incus_dhcp_enabled = false`.
  - Make sure every container has a valid static IP address.
  - Make sure `incus_gateway` is configured.
  - Check that the IP address, gateway, and DNS settings are correct.

### Bind Mount Permission Denied

- Verify that `shift = true` is set for the bind mount if needed.
- Ensure the host kernel is at least **Linux 5.12** for idmapped mounts. Check with:

  ```shell
  uname -r
  ```

- Alternatively, adjust host directory permissions (e.g. `chmod 755`).
- Running a container as privileged (`security.privileged = true`) may be another option, but it is
  not recommended for production.

<!-- TODO -->

## TODO

- [x] DHCP support
- [x] Static IP assignment
- [x] Support Incus-managed and unmanaged bridges
- [x] Cross-distribution cloud-init script
- [x] CPU and memory limits
- [x] Outputs
- [ ] Use Incus profiles/projects in `modules/instances/main.tf`
- [x] Bind mounts (host directories)
- [ ] Managed storage volumes (zfs/btrfs/dir)
- [ ] Multiple networks
- [x] Support nested virtualization
- [x] Support adding extra configuration options from
      [Incus instance options](https://linuxcontainers.org/incus/docs/main/reference/instance_options/)
- [ ] Support adding extra storage pools

<!-- LICENSE -->

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This is an open source project under the MIT license.

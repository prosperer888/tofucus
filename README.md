# OpenTofu Module: Incus Containers

`tofucus` – OpenTofu module for managing Incus containers.

An OpenTofu configuration that deploys [incus](https://linuxcontainers.org/incus/) containers with
**static IPs, resource limits, cloud‑init provisioning and optional bind mounts (host
directories)**.

This module uses opentofu provider from
[lxc/incus](https://search.opentofu.org/provider/lxc/incus/latest), incus opentofu provider,
`Resources` and `Data Sources` configurations can be view at
[documentations](https://search.opentofu.org/provider/lxc/incus/latest).

> [!WARNING]
>
> Only works with incus images that include cloud-init (usually images with `/cloud` in the name).
> This module supports **containers only** (not Incus virtual machines).

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
- [Usage](#usage)
  - [Adding or Removing Containers](#adding-or-removing-containers)
  - [Quick Start](#quick-start)
  - [Outputs](#outputs)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
  - [Container created but cannot SSH](#container-created-but-cannot-ssh)
- [TODO](#todo)
- [License](#license)

<!-- tocstop -->

</details>

<!-- DESCRIPTION -->

## Description

This opentofu configuration will:

- Create multiple containers using a simple map variable
- Assign **static IPv4 addresses** on a bridged network (`incusbr0`)
- Set **CPU and memory** limits per container
- **bind mounts (host directories)** into containers
- Automatically:
  - Create a non‑root user with passwordless sudo
  - Adds SSH key
  - Installs common packages (`curl`, `git`, `openssh-server`, `python3`)
  - Enables and starts SSH
  - Works across **debian/ubuntu, redhat/fedora, and arch linux** if they have an incus cloud image.

<!-- SUPPORTED PLATFORMS -->

## Supported Platforms (container images)

- Supported for **debian/ubuntu, redhat family, and arch linux** using incus cloud images (images
  ending with /cloud). Use incus command `incus image list images:` to search available images.

<!-- REQUIREMENTS -->

## Requirements

### OpenTofu

- OpenTofu >= 1.9.1
- Provider [`lxc/incus`](https://registry.terraform.io/providers/lxc/incus/latest) >= 0.3.1
  (automatically downloaded on `tofu init`)

### Incus

- Incus installed and initialised (`incus admin init`)
- A **bridged network** (default: `incusbr0`) with an available IP range. (`incus network list`)
- A **storage pool** (default: `default`)
- User must have permission to access the incus socket (usually member of the `incus-admin` group)

Incus `cloud` images available (example: **debian/12/cloud**)

<!-- Project Structure -->

## Project Structure

```shell
: tree
.
├── main.tf
├── modules
│   └── instances
│       ├── main.tf
│       ├── outputs.tf
│       ├── template
│       │   └── cloud-init.yaml.tftpl
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

| Variable             | Type                                          |        Required        | Description                                                                                                                                                 |
| -------------------- | --------------------------------------------- | :--------------------: | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `incus_instances`    | `map(object({ip, cpu, memory, bind_mounts}))` |          yes           | Container definitions including IP, CPU, memory, and optional bind mounts.<br><br>See below example on how to map `incus_instances`                         |
| `incus_image`        | `string`                                      |          yes           | Image name. (cloud image required. E.G. `debian/12/cloud`).                                                                                                 |
| `incus_storage_pool` | `string`                                      |          yes           | Storage pool name (e.g. `default`).                                                                                                                         |
| `incus_network`      | `string`                                      |          yes           | Network interface (e.g. `incusbr0`).                                                                                                                        |
| `incus_nic_type`     | `string`                                      | yes(default `bridged`) | Type of network interface. Use `bridged` for attaching to an existing incus bridge, or `macvlan` for direct physical network access. Defaults to `bridged`. |
| `ssh_public_key`     | `string`                                      |          yes           | Content of your SSH public key.                                                                                                                             |
| `username`           | `string`                                      |          yes           | Non‑root user name inside containers. (default: `incus`)                                                                                                    |
| `timezone`           | `string`                                      |           no           | Timezone (default: `UTC`).                                                                                                                                  |

Structure for `incus_instances`

```hcl
incus_instances = {
  "<name>" = {
    ip     = string
    cpu    = number
    memory = string

    # optional
    bind_mounts = [
      {
        host_path  = string
        mount_path = string
        readonly   = bool
        shift      = bool
      }
    ]
  }
}
```

Required container configuration for `incus_instances`.

- `ip` - static IPv4 address within incus network subnet (e.g. 10.150.19.50)
- `cpu` - number of CPU cores allocated to the container (e.g. 2)
- `memory` - memory limit with unit (e.g. "2GiB" or "512MiB")

Make sure the IP address is not already in used and use same subnet. Use `incus network list` to
find the subnet (look for **"inet"** address of the bridge).

<https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container>

Optionally mount host directories into containers (bind mounts)

- `host_path` - existing directory on the host (use absolute path, e.g. /home/user/data)
- `mount_path` - destination path inside the container (e.g. /media)
- `readonly` - set to true for read‑only access (default false)
- `shift` - enable idmapped mounts to fix permission issues

> [!NOTE]
>
> The `host_path` must already exist on the host system. OpenTofu/Incus will not create the
> directory automatically.

<!-- -->

> [!WARNING]
>
> Bind mounts expose host directories directly to containers:
>
> - Deleting files inside the container will delete them on the host
> - Incorrect permissions may break applications
> - Use `shift = true` when needed to avoid permission issues
> - Always double-check paths before running `tofu apply`

**See below example on how to map `incus_instances`**

<!-- EXAMPLE -->

**Example** `terraform.tfvars`

```hcl
# terraform.tfvars

# Required container configuration. Each entry must include:
#   ip     - static IPv4 address within your Incus network subnet
#   cpu    - number of CPU cores allocated to the container
#   memory - memory limit with unit (MiB or GiB)
#   bind_mounts - (optional) list of host directories to bind mount into the container
incus_instances = {
  "media" = {
    ip     = "10.150.19.50"
    cpu    = 2
    memory = "2GiB"

    # optional
    bind_mounts = [
      {
        host_path  = "/mnt/media"
        mount_path = "/media"
        readonly   = false
        shift      = true
      }
    ]
  }
  "db"   = { ip = "10.150.19.51", cpu = 1, memory = "1GiB" }
}

incus_image          = "debian/12/cloud"
incus_network        = "incusbr0"
incus_storage_pool   = "default"
ssh_public_key       = "ssh-ed25519 AAAAC3... user@host"
username             = "incus"
timezone             = "Asia/Kuala_Lumpur"
```

> [!NOTE]
>
> The `memory` field in `incus_instances` **only accepts values in `MiB` or `GiB`** (e.g. `512MiB`,
> `2GiB`). Other units like `MB`, `GB`, or `KiB` are not allowed by this module.

<!-- USAGE -->

## Usage

- Clone the project

  Copy the [terraform.tfvars.example](terraform.tfvars.example) variables into `terraform.tfvars`
  and update our SSH key and desired containers.

  ```shell
  cd tofucus
  cp terraform.tfvars.example terraform.tfvars
  ```

- Initialize opentofu

  ```shell
  tofu init
  ```

- Review the plan

  ```shell
  tofu plan
  ```

- Apply the configuration

  ```shell
  tofu apply -auto-approve
  # or
  tofu apply -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)" -auto-approve
  ```

  After creation, opentofu outputs the container names and ip addresses.

- Wait for cloud‑init to finish (approx. 30 seconds)

- SSH into a container

  ```shell
  ssh incus@10.150.19.50
  ```

- Destroy everything

  ```shell
  tofu destroy -auto-approve
  ```

### Adding or Removing Containers

- To add new container, simply append a new entry to the `incus_instances` map in
  `terraform.tfvars`.
- To remove a container, comment out or delete its entry.

```hcl
incus_instances = {
  "web" = { ip = "10.150.19.50", cpu = 2, memory = "2GiB" },
  # "db"  = { ip = "10.150.19.51", cpu = 1, memory = "1GiB" }   # removed
  "cache" = { ip = "10.150.19.52", cpu = 1, memory = "1GiB" }   # added
}
```

Attaching shared directory to containers

**Common Use Case:**

- Share media between containers (e.g. Jellyfin, Sonarr):
  - Mount the same host directory (e.g. `/mnt/media`) into multiple containers
- Persist important data:
  - Store configs and repositories on the host using bind mounts

```hcl
incus_instances = {
  "jellyfin" = {
    ip     = "10.150.19.50"
    cpu    = 2
    memory = "2GiB"
    bind_mounts = [
      {
        host_path  = "/mnt/media"
        mount_path = "/media"
        shift      = true
      }
    ]
  }

  "sonarr" = {
    ip     = "10.150.19.51"
    cpu    = 1
    memory = "1GiB"
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

Then run `tofu plan` to review the changes, then followed by `tofu apply`.

> [!NOTE]
>
> Removing a container, will destroy its filesystem – any data inside the container will be lost.
>
> Bind mount directories remain on the host system. OpenTofu/Incus will not destroy bind directory
> when we destroy the containers

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

Example output after apply:

```shell
containers = {
  "web" = {
    "ip" = "10.150.19.50"
    "name" = "web"
  }
  "db" = {
    "ip" = "10.150.19.51"
    "name" = "db"
  }
}
reminder = "Container is up! Please wait ~30 seconds for the setup script to finish before SSHing."
```

SSH into container:

```shell
ssh incus@10.150.19.50
```

<!-- HOW IT WORKS -->

## How It Works

- The root [main.tf](main.tf) calls the instances module once per entry in `var.incus_instances`.
- The module `modules/instances/main.tf`:
  - Creates an `incus_instance` resource with the specified **name, image, CPU, memory**.
  - Attaches a root disk device (storage pool) and an **eth0** network device (bridged with static
    IP).
  - Apply a cloud‑init user‑data template (cloud-init.yaml.tftpl).

- **Optionally** attaches additional disk devices for bind mounts:
  - Maps host directories into the container filesystem
  - Useful for sharing media, repositories, or configs

- Cloud‑init on the container:
  - Creates the user and adds the SSH key.
  - Writes a helper script (/usr/local/bin/setup-lab.sh) that detects the distribution and installs
    packages using apt, dnf, or pacman.
  - Runs the script via `runcmd`.

- The module output shows container names and their assigned IP addresses.

<!-- TROUBLESHOOT -->

## Troubleshooting

### Container created but cannot SSH

- Wait ~30 seconds (cloud-init may still be running)
- Check cloud-init status:

  ```shell
  incus exec <container> -- cloud-init status
  ```

- SSH service not running

  ```shell
  incus exec <container> -- systemctl status ssh
  # or
  incus exec <container> -- systemctl status sshd
  ```

- Check setup logs

  ```shell
  incus exec <container> -- cat /var/log/lab-setup.log
  ```

- Bind mount permission denied (can't write)
  - Verify `shift = true` is set in `terraform.tfvars` for the bind mount.
  - Ensure the host kernel is at least **Linux 5.12** (idmapped mounts). Check with `uname -r`.
  - Alternatively, adjust host directory permissions (e.g. `chmod 755`) or run the container as
    privileged (`security.privileged = true` – not recommended for production).

<!-- TODO -->

## TODO

- [x] Static IP assignment
- [x] Cross‑distribution cloud‑init script
- [x] CPU and memory limits
- [x] Outputs
- [ ] Use incus profile/project in `modules/instances/main.tf`
- [x] bind mounts (host directories)
- [ ] Managed storage volumes (zfs/btrfs/dir)
- [ ] Multiple networks

<!-- LICENSE -->

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This is an open source project under the MIT license.

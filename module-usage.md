# OpenTofu Module Usage Guide

This repository is a reusable **OpenTofu** module that deploys **Incus** containers with static IPs,
resource limits, and cloud‑init provisioning.

This guide explains how to use this module in other projects.

> [!WARNING]
>
> Only works with incus images that include cloud-init (usually images with `/cloud` in the name).
> This module supports **containers only** (not Incus virtual machines).

## Table Of Contents

<details>
  <summary>Click to expand</summary>

<!-- toc -->

- [Basic Idea](#basic-idea)
- [Example Project Structure](#example-project-structure)
- [Requirements](#requirements)
- [main.tf](#maintf)
  - [A. Use Root Module](#a-use-root-module)
  - [B. Use Child Module](#b-use-child-module)
- [variables.tf](#variablestf)
- [terraform.tfvars](#terraformtfvars)
- [versions.tf](#versionstf)
- [.gitignore](#gitignore)
- [Usage](#usage)
- [Destroy Resources](#destroy-resources)
- [Notes](#notes)

<!-- tocstop -->

</details>

## Basic Idea

Use with other projects that want to use **Incus** containers.

We do NOT run it directly. Instead, we'll call it from another project using a `main.tf` file.

## Example Project Structure

```shell
my-project
├── .gitignore
├── infra
│   ├── main.tf
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── versions.tf
└── my-project-files
```

## Requirements

- Incus installed and initialized (`incus admin init`)
- User must have access to the **Incus socket** (member of `incus-admin`)
- OpenTofu >= 1.9.1

## main.tf

There are 2 options to create the `main.tf` file:

- Use **Root Module** (simple, recommended)
- Use **Child Module** (`modules/instances`) (more control)

> [!NOTE]
>
> When `map` or `mapping` is mentioned, it means variables defined like:
>
> ```hcl
> # Required container configuration. Each entry must include:
> #   ip     - static IPv4 address within your Incus network subnet
> #   cpu    - number of CPU cores allocated to the container
> #   memory - memory limit with unit (MiB or GiB)
> #   bind_mounts - (optional) list of host directories to bind mount into the container
> incus_instances = {
>   "media" = {
>     ip     = "10.150.19.50"
>     cpu    = 2
>     memory = "2GiB"
>
>     # optional
>     bind_mounts = [
>       {
>         host_path  = "/mnt/media"
>         mount_path = "/media"
>         readonly   = false
>         shift      = true
>       }
>     ]
>   }
>   "db"   = { ip = "10.150.19.51", cpu = 1, memory = "1GiB" }
> }
> ```

### A. Use Root Module

- Supports multiple containers
- Uses `incus_instances` map directly
- No loop (for_each) needed in this file. (handled by **tofucus** module repository)
- Simple setup

```hcl
// https://opentofu.org/docs/language/modules/sources
// https://opentofu.org/docs/language/modules/sources/#support-for-variable-and-local-evaluation
locals {
  modules_repo = "https://github.com/prosperer888/tofucus.git"
  modules_version = "?ref=v1.1.1"
}

module "containers" {
  // https://opentofu.org/docs/language/modules/sources/#modules-in-package-sub-directories
  source = "git::${local.modules_repo}${local.modules_version}"

  incus_instances    = var.incus_instances
  incus_image        = var.incus_image
  incus_network      = var.incus_network
  incus_storage_pool = var.incus_storage_pool
  ssh_public_key     = var.ssh_public_key
  username           = var.username
  timezone           = var.timezone
}

output "containers" {
  value = module.containers.containers
}

output "reminder" {
  value = module.containers.reminder
}
```

### B. Use Child Module

This directly uses the **Child Module** inside `modules/*` directory.

- Requires looping (`for_each`) over `incus_instances` in **this** `main.tf` file
- More flexible
- Slightly more complex

```hcl
locals {
  modules_repo = "https://github.com/prosperer888/tofucus.git"
  modules_version = "?ref=v1.1.1"
}

module "containers" {
  source = "git::${local.modules_repo}//modules/instances${local.modules_version}"

  for_each = var.incus_instances

  // variables name from 'modules/instances/variables.tf' file
  instance_name = each.key
  ipv4_address  = each.value.ip
  cpu_limit     = each.value.cpu
  memory_limit  = each.value.memory
  bind_mounts   = each.value.bind_mounts

  image         = var.incus_image
  storage_pool  = var.incus_storage_pool
  network_name  = var.incus_network
  nic_type      = var.incus_nic_type

  ssh_key       = var.ssh_public_key
  username      = var.username
  timezone      = var.timezone
}

output "containers" {
  value = {
    for k, v in module.containers :
    k => v.container
  }
}

output "reminder" {
  value = "Container is up! Please wait ~30 seconds for the setup script to finish before SSHing."
}
```

> [!NOTE]
>
> When using the **Child Module**, this `main.tf` structure is the same as the root `main.tf` inside
> the **tofucus** repository.
>
> The only difference:
>
> - Replace local source:
>
>   ```hcl
>   source = "./modules/instances"
>   ```
>
> - With remote source:
>
>   ```hcl
>   source = "git::https://gitea.local/myuser/tofucus.git//modules/instances"
>   ```

## variables.tf

Only define variables that we want to customize. We can omit variables that we don't use. For
example below, `incus_nic_type` is omit from variables.tf file.

```hcl
variable "incus_instances" {
  type = map(object({
    ip     = string
    cpu    = number
    memory = string
    bind_mounts  = optional(list(object({
      host_path  = string
      mount_path = string
      readonly   = optional(bool, false)
      # https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container
      shift      = optional(bool, false)
    })), [])
  }))
}

variable "incus_image" {
  type    = string
  default = "debian/12/cloud"
}

variable "incus_network" {
  type    = string
  default = "incusbr0"
}

variable "incus_storage_pool" {
  type    = string
  default = "default"
}

variable "ssh_public_key" {
  type = string
  sensitive = true
}

variable "username" {
  type    = string
  default = "incus"
}

variable "timezone" {
  type    = string
  default = "UTC"
}
```

## terraform.tfvars

> [!NOTE]
>
> Check Incus network subnet:
>
> ```shell
> incus network list
> ```
>
> Example: `incusbr0` are using `10.150.19.1/24`
>
> This means usable IPs are: `10.150.19.2 – 10.150.19.254`
>
> Use only IPs within this range in `incus_instances`.

**Do NOT** commit this file to git. It may contain sensitive data.

```hcl
# Required container configuration.
#   ip     - static IPv4 address within incus network subnet (e.g. 10.150.19.50)
#   cpu    - number of CPU cores allocated to the container (e.g. 2)
#   memory - memory limit with unit (e.g. "2GiB" or "512MiB")
# Ensure the IP address is not already used and falls inside the subnet.
# Use 'incus network list' to find the subnet (look for "inet" address of the bridge).
#
# https://linuxcontainers.org/incus/docs/main/faq/#can-i-bind-mount-my-home-directory-in-a-container
# Optional bind mounts from host to container.
#   host_path  - existing directory on the host (use absolute path, e.g. /home/user/data)
#   mount_path - destination path inside the container (e.g. /media)
#   readonly   - set to true for read‑only access (default false)
#   shift      - enable idmapped mounts to fix permission issues
incus_instances = {
  "c1" = {
    ip     = "10.150.19.50"
    cpu    = 2
    memory = "2GiB"
    bind_mounts = [
      {
        host_path  = "/home/user/data"
        mount_path = "/media"
        readonly   = false
        shift      = true
      }
    ]
  }
  "c2" = { ip = "10.150.19.51", cpu = 1, memory = "1GiB" }
}
# this OpenTofu module only accept images that end with '/cloud'
incus_image        = "debian/12/cloud"
incus_network      = "incusbr0"
incus_storage_pool = "default"
ssh_public_key     = "ssh-ed25519 AAAA... user@host"
username           = "incus"
timezone           = "Asia/Kuala_Lumpur"
```

## versions.tf

`versions.tf` is optional. We can place it inside `main.tf` (**above locals {}**) if prefer fewer
files. E.G. Copy the content below and paste it into `main.tf` file.

```hcl
terraform {
  required_version = ">=1.9.1"
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">=0.3.1"
    }
  }
}
```

## .gitignore

```txt
.terraform/
*.tfstate
*.tfstate.backup
terraform.tfvars
*.log
```

## Usage

Run the following commands:

```shell
cd infra
tofu init
tofu plan

tofu apply -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)"

# (optional) run provisioning scripts (e.g. Ansible)

# back to 'my-project' directory
cd ../my-project

# and run whatever code 'my-project' is using. E.G.
# web server, DB cluster ETC
```

> [!NOTE]
>
> We can pass different environment `*.tfvars` file like below:
>
> ```shell
> tofu apply -var-file="dev.tfvars"
> ```
>
> OpenTofu/Terraform loads variables in below order:
>
> 1. `terraform.tfvars` (auto)
> 2. `*.auto.tfvars`
> 3. `-var-file=*.tfvars` (manual override, highest priority)
> 4. `-var=*` (cli override, highest priority of all)

## Destroy Resources

```shell
cd infra
tofu destroy
```

## Notes

- Always use cloud images (e.g. `debian/12/cloud`)
- Do NOT commit `terraform.tfvars`
- Use `.gitignore` to exclude secrets
- We can scale by adding more instances in `incus_instances`
- Pin module version using `?ref=` to avoid unexpected changes

# Remote Incus Connection

[Terraform Provider For Incus](https://search.opentofu.org/provider/lxc/incus/latest#description)

By default, opentofu connects to the local incus daemon through the Unix socket:

```hcl
provider "incus" {
  generate_client_certificates = false
  accept_remote_certificate    = false
  default_remote               = "local"

  remote {
    name    = "local"
    address = "unix://"
  }
}
```

> [!NOTE]
>
> **No** trust token is required when using the local Unix socket.

For remote incus servers (for example CI/CD runners, management hosts, or workstations), configure a
remote HTTPS endpoint instead.

> [!NOTE]
>
> For a remote incus server, there is no need to install incus on the control machine. The opentofu
> provider communicates directly with the remote incus API.

## 1. Enable the Incus API

> [!NOTE]
>
> During `incus init`, incus normally configures the HTTPS API to listen on port `8443`.

On the **incus server**, verify the API is listening:

```bash
incus config show
```

Look for:

```shell
core.https_address: '[::]:8443'
```

If not configured:

```bash
incus config set core.https_address :8443
```

Reference:

- [incus config set](https://linuxcontainers.org/incus/docs/main/reference/manpages/incus/config/set)

## 2. Generate a Trust Token

On the **incus server:**

```bash
incus config trust add homelab
```

Save the generated token.

> [!NOTE]
>
> `homelab` can be any name we want, above example use `homelab` for simplicity

Reference:

- [incus config trust add](https://linuxcontainers.org/incus/docs/main/reference/manpages/incus/config/trust/add/#incus-config-trust-add-md)

## 3. Configure OpenTofu Incus Provider

Example:

> [!WARNING]
>
> Setting `accept_remote_certificate = true` automatically accepts the server's TLS certificate
> without verification. For production, consider using a trusted CA. Check
> [PKI Support](https://search.opentofu.org/provider/lxc/incus/latest#pki-support)

```hcl
provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true
  # 'homelab' are from when we run 'incus config trust add homelab' in step 2 above
  default_remote               = "homelab"

  remote {
    name    = "homelab"
    address = "https://192.168.1.100:8443"
    token   = "<generated-token>"
  }
}
```

> [!NOTE]
>
> For CI/CD we can use
> [Environment Variable](https://search.opentofu.org/provider/lxc/incus/latest#environment-variable-remote)
>
> Provide the **trust token** through environment variables, and set the value in **Actions
> Secrets** section in our git hosting service (Forgejo, Gitea or Github)
>
> ```bash
> export INCUS_REMOTE="homelab"
> export INCUS_ADDR="https://192.168.1.100:8443"
> export INCUS_TOKEN="${{ secrets.INCUS_TOKEN }}"
> ```
>
> Environment variables override values defined in the provider configuration, useful for CI/CD
> pipelines.

**For this repository, the `provider.tf` file look like below:**

```hcl
provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true
  default_remote               = var.incus_remote_name

  remote {
    name    = var.incus_remote_name
    address = var.incus_remote_address
    token   = var.incus_remote_token
  }
}
```

The variables can be set at `terraform.tfvars` file

## 4. Apply

Run opentofu normally:

```bash
tofu init
tofu plan
tofu apply
```

The provider will automatically:

- Trust the remote server certificate.
- Generate client certificates if needed.
- Register the client with the incus server using the trust token.

---

## Resetting/Testing from Scratch

When in **development stage**, we can **reset/remove** trusted list like below. Incus
**token/certificates** located at `~/.config/incus`

### On the Incus Server

```bash
# check incus trusted list
incus config trust list

# Remove trusted list
incus config trust remove <fingerprint>
```

### On Local Machine

```bash
# If we have the 'Incus client' installed (optional but convenient)
# (Optional) List remote configuration
incus remote list

# (Optional) Remove incus remote configuration from local machine
incus remote remove <remote-name>

# Remove local client certificates and config
rm -rf ~/.config/incus

# Clean opentofu artifacts
rm -rf .terraform .terraform.lock.hcl terraform.tfstate
```

Then we can continue from [Step 2. Generate a Trust Token](#2-generate-a-trust-token) above.

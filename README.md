# packer

Packer templates for Proxmox VE.

All active templates use the `proxmox-iso` plugin, HashiCorp Vault for Proxmox credentials, and local `*.auto.pkrvars.hcl` files for build-specific settings (network, SSH keys, passwords).

## Quick start

1. Create `env.sh` (already gitignored, do not commit):

```bash
export VAULT_TOKEN='s.xxxxxxxxxxxxxxx'
export VAULT_ADDR='http://xx.xx.xx.xx:8200'
```

2. Store Proxmox API credentials in Vault:

```bash
vault kv put secrets/proxmox \
  url="https://pve.example.com:8006/api2/json" \
  username="root@pam!packer" \
  token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

3. Build a template (Debian 13 example):

```bash
source env.sh
cd debian/debian-13
cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl
# edit debian.auto.pkrvars.hcl: http_host, ssh_password, ssh_public_key
packer init .
packer build .
```

Debug mode:

```bash
export PACKER_LOG=1
packer build --debug .
```

## Build-specific variables you must set

Each template ships with an `*.auto.pkrvars.hcl.example` file. Copy it to `*.auto.pkrvars.hcl` and fill in at least:

| Variable | Example | Purpose |
|----------|---------|---------|
| `http_host` / `http_interface` | `192.168.1.10` | Interface/IP the installer VM uses to fetch preseed/cloud-init |
| `bridge` | `vmbr1` | Proxmox bridge for the build VM |
| `ssh_password` / `ssh_password_hash` | `CHANGE_ME` / `$6$rounds=4096$...` | Default user password or SHA-512 hash |
| `ssh_public_key` / `ssh_public_keys` | `ssh-ed25519 AAA...` | SSH public key(s) to authorize |
| `iso_file` | `local:iso/debian-13.5.0-amd64-netinst.iso` | ISO image uploaded to PVE storage |

> `*.auto.pkrvars.hcl` is gitignored. Never commit real passwords or SSH keys.

## Generating a SHA-512 password hash (Ubuntu cloud-init)

```bash
mkpasswd --method=sha-512 --rounds=4096
```

Paste the output into the `ssh_password_hash` variable.

## Templates

| OS | Directory | Status | Notes |
|----|-----------|--------|-------|
| Debian 13 | `debian/debian-13/` | ✅ Active | Netinst preseed, Tsinghua mirror, cloud-init |
| Debian 11 | `debian/debian-11/` | ⚠️ Legacy | DVD-based preseed build |
| Ubuntu 24.04 | `ubuntu/ubuntu-24.04/` | ✅ Active | Cloud-init autoinstall, Tsinghua mirror |
| Ubuntu 22.04 | `ubuntu/ubuntu-22.04/` | ✅ Active | Cloud-init autoinstall, Tsinghua mirror |
| Ubuntu 20.04 | `ubuntu/ubuntu-20.04/` | ⚠️ Legacy | Cloud-init autoinstall, Tsinghua mirror |
| CentOS 7 | `legacy/centos-7/` | ❌ EOL | Archived; CentOS 7 reached EOL on 2024-06-30 |

## Skill

See `skills/pve-debian-packer-template/` for the full workflow of building a Debian 13 template on Proxmox VE with Packer, including preseed, cloud-init, SSH key injection, domestic mirror setup, and troubleshooting HTTP/1.1 keep-alive issues behind OpenClash.

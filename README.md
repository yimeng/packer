# packer

Packer templates for Proxmox VE.

## Quick start

Create `env.sh` (gitignored, do not commit):

```bash
export VAULT_TOKEN='s.xxxxxxxxxxxxxxx'
export VAULT_ADDR='http://xx.xx.xx.xx:8200'
```

Load it and build:

```bash
source env.sh
cd debian/debian-13
cp debian-13.auto.pkrvars.hcl.example debian-13.auto.pkrvars.hcl
# edit debian-13.auto.pkrvars.hcl with your network and credentials
packer init .
packer build .
```

Debug mode:

```bash
export PACKER_LOG=1
packer build --debug .
```

## Vault secrets

The Debian 13 template reads Proxmox credentials from Vault path `secrets/proxmox`:

- `url`      – Proxmox API URL, e.g. `https://pve.example.com:8006/api2/json`
- `username` – API token name, e.g. `root@pam!packer`
- `token`    – API token secret

## Templates

| OS          | Directory           | Notes                                         |
|-------------|---------------------|-----------------------------------------------|
| Debian 11   | `debian/debian-11/` | Legacy DVD-based preseed build                |
| Debian 13   | `debian/debian-13/` | Netinst preseed, Tsinghua mirror, cloud-init  |
| Ubuntu 20.04| `ubuntu/ubuntu-20.04/`| Cloud-init build                              |
| Ubuntu 22.04| `ubuntu/ubuntu-22.04/`| Cloud-init build                              |
| CentOS 7    | `centos/`           | Legacy HCL build                              |

## Skill

See `.kimi-code/skills/pve-debian-packer-template/` for the full workflow of building a Debian 13 template on Proxmox VE with Packer, including preseed, cloud-init, SSH key injection, domestic mirror setup, and troubleshooting HTTP/1.1 keep-alive issues behind OpenClash.


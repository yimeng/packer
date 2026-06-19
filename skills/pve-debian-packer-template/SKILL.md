# 使用 Packer 在 Proxmox VE 上构建 VM 模板

## 描述

本 skill 描述如何在 Proxmox VE (PVE) 上使用 HashiCorp Packer 从零构建 Debian / Ubuntu / NixOS 虚拟机模板。

覆盖范围：
- 准备 PVE 环境、ISO 镜像与 API token；
- 使用 preseed、cloud-init autoinstall 或 NixOS 声明式配置自动化安装；
- 配置默认用户、SSH 公钥、基础工具、cloud-init；
- 将 VM 转换为 PVE 模板；
- 处理国内镜像源与 OpenClash 下的 HTTP/1.1 keep-alive 间歇性卡住问题；
- 管理旧模板与 EOL 系统。

## 适用场景

- 需要可重复、可版本化的 Debian/Ubuntu/NixOS VM 模板；
- 模板需要预装常用工具、SSH key、cloud-init；
- 希望克隆出的 VM 自动根据 VM name 设置 hostname；
- 想尝试声明式基础设施（NixOS）；
- 在国内网络环境下构建，需要默认使用清华/国内源；
- 需要清理仓库中硬编码的密码、SSH key 等敏感信息。

## 前置条件

- Proxmox VE 节点可访问，已创建 API token；
- 已上传对应 OS 的 ISO 到 PVE 存储；
- 运行 Packer 的机器能访问 PVE API，且能被安装器访问（用于拉取 preseed/cloud-init）；
- 已配置 HashiCorp Vault（或准备用 `*.auto.pkrvars.hcl` 注入凭据）。

## 仓库结构

```
debian/debian-13/
├── debian.pkr.hcl                   # Packer 主配置
├── debian.auto.pkrvars.hcl.example  # 示例变量
└── cloud-init/
    └── preseed.cfg.tmpl             # preseed 模板

debian/debian-12/
├── debian.pkr.hcl
├── debian.auto.pkrvars.hcl.example
└── cloud-init/
    └── preseed.cfg.tmpl

ubuntu/ubuntu-24.04/
├── ubuntu.pkr.hcl
├── ubuntu.auto.pkrvars.hcl.example
└── cloud-init/
    ├── meta-data
    └── user-data.tmpl               # cloud-init 模板

nixos/nixos-24.11/
├── nixos.pkr.hcl
├── nixos.auto.pkrvars.hcl.example
├── configuration.nix.tpl            # NixOS 系统配置模板
└── install-nixos.sh                 # 分区、安装、重启脚本
```

CentOS 7 已 EOL，归档在 `legacy/centos-7/`。

## 快速开始

### 1. 配置 Vault

创建 `env.sh`（已 gitignore）：

```bash
export VAULT_TOKEN='s.xxxxxxxxxxxxxxx'
export VAULT_ADDR='http://xx.xx.xx.xx:8200'
```

写入 Vault（路径 `secrets/proxmox`）：

```bash
vault kv put secrets/proxmox \
  url="https://pve.example.com:8006/api2/json" \
  username="root@pam!packer" \
  token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 2. 准备本地变量

```bash
cd debian/debian-13              # 或 ubuntu/ubuntu-24.04 等
cp debian.auto.pkrvars.hcl.example debian.auto.pkrvars.hcl
# 编辑 debian.auto.pkrvars.hcl：
#   http_host / http_interface - Packer 机器 IP/接口，安装器用来下载配置
#   bridge                     - Proxmox bridge
#   ssh_password / ssh_password_hash - 默认用户密码或哈希
#   ssh_public_key / ssh_public_keys - 要写入 authorized_keys 的公钥
```

### 3. 构建

```bash
source env.sh
packer init .
packer build .
```

构建完成后，PVE 上会出现对应 VMID 的模板。

## 各模板差异

| OS | 安装方式 | 默认 VMID | 默认用户 | 必须变量 |
|----|---------|----------|---------|---------|
| Debian 13 | preseed | 9000 | `yimeng` | `http_host`, `ssh_password`, `ssh_public_key` |
| Debian 12 | preseed | 9005 | `yimeng` | `http_host`, `ssh_password`, `ssh_public_key` |
| Debian 11 | preseed | 9003 | `packer` | `http_interface`, `ssh_password` |
| Ubuntu 24.04 | cloud-init autoinstall | 9004 | `ubuntu` | `http_interface`, `ssh_password_hash`, `ssh_public_keys` |
| Ubuntu 22.04 | cloud-init autoinstall | 9001 | `ubuntu` | `http_interface`, `ssh_password_hash`, `ssh_public_keys` |
| Ubuntu 20.04 | cloud-init autoinstall | 9002 | `ubuntu` | `http_interface`, `ssh_password_hash`, `ssh_public_keys` |
| NixOS 24.11 | live ISO + nixos-install | 9010 | `yimeng` | `bridge`, `ssh_public_key`, `iso_file` |

## 生成 Ubuntu cloud-init 密码哈希

```bash
mkpasswd --method=sha-512 --rounds=4096
```

将输出写入 `ssh_password_hash`。不要提交到仓库。

## NixOS 模板说明

NixOS 模板使用与其他模板不同的安装流程：

1. Packer 启动 NixOS minimal live ISO；
2. `boot_command` 登录 root、设置临时密码、启动 sshd；
3. Packer 通过 SSH 上传 `configuration.nix` 和 `install-nixos.sh`；
4. `install-nixos.sh` 自动分区、格式化、运行 `nixos-generate-config`、复制配置、执行 `nixos-install`；
5. 脚本重启后，Packer 使用 `configuration.nix` 中配置的 SSH key 重新连接并验证。

`configuration.nix.tpl` 中已配置：
- GRUB bootloader
- DHCP 网络
- OpenSSH（禁止 root/密码登录，仅 key）
- 默认用户 + sudo
- 清华 Nix binary cache mirror
- 基础工具包（vim、git、curl、htop、jq）

### 注意事项

- NixOS 安装需要从网络下载 closure，首次构建可能较慢；
- `iso_file` 必须指向你上传到 PVE 的 NixOS 24.11 minimal ISO；
- 示例 ISO 文件名是占位符，请从 [nixos.org](https://nixos.org/download/) 下载最新版本并更新变量。

## Cloud-init 与 hostname

所有模板均启用 `cloud-init`。在 PVE 中克隆模板时：

```bash
qm clone 9000 101 --name my-vm --full true
```

`cloud-init` 会在首次启动时把 hostname 设为 `my-vm`。

## 故障排查：国内源 HTTP/1.1 keep-alive 卡住

### 现象

`curl --http1.1 http://mirrors.tuna.tsinghua.edu.cn/debian/` 偶尔卡住；`--http1.0` 或 `-H "Connection: close"` 正常；`deb.debian.org` 正常。

### 诊断命令

```bash
# 复现
timeout 15 curl -v --http1.1 -o /dev/null -s http://mirrors.tuna.tsinghua.edu.cn/debian/
timeout 15 curl -v --http1.0 -o /dev/null -s http://mirrors.tuna.tsinghua.edu.cn/debian/

# 检查 OpenClash 是否 bypass 国内 IP（在路由器上执行）
ipset test china_ip_route 101.6.15.130
iptables -t nat -L openclash -v -n
```

### 处理

Debian 模板在 preseed 中已写入：

```text
Acquire::http::Pipeline-Depth "0";
```

该配置能降低 apt 触发 keep-alive 卡住的概率。若问题持续，可临时切回 `deb.debian.org`，或避免使用 `mirrors.163.com`（在该环境下 consistently 卡住）。

## 离线修改已有模板磁盘

如果模板已存在但想改源，可离线挂载基础盘：

```bash
VMID=9000
sudo qm stop <linked-clone-vmid>
sudo lvchange -prw /dev/pve/base-${VMID}-disk-0
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 -f raw /dev/pve/base-${VMID}-disk-0
mkdir -p /tmp/mnt-${VMID}
sudo mount /dev/nbd0p1 /tmp/mnt-${VMID}

# 修改 /tmp/mnt-${VMID}/etc/apt/sources.list
# 修改 /tmp/mnt-${VMID}/etc/apt/apt.conf.d/99nopipelining

sudo umount /tmp/mnt-${VMID}
sudo qemu-nbd -d /dev/nbd0
sudo lvchange -pr /dev/pve/base-${VMID}-disk-0
sudo qm start <linked-clone-vmid>
```

## 安全注意事项

- 不要把 PVE API token、root 密码、SSH 私钥提交到仓库；
- `*.auto.pkrvars.hcl` 已加入 `.gitignore`；
- 使用 Vault 或环境变量注入凭据；
- 密码和公钥通过 Packer 变量在渲染时注入，不会出现在最终仓库中；
- EOL 系统（如 CentOS 7）归档在 `legacy/`，保留原始文件仅作历史参考，不建议继续使用。

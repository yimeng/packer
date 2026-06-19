# 使用 Packer 在 Proxmox VE 上构建 Debian 模板

## 描述

本 skill 描述如何在 Proxmox VE (PVE) 上使用 HashiCorp Packer 从零构建一个 Debian 虚拟机模板。

覆盖范围：
- 准备 PVE 环境、ISO 镜像与 API token；
- 使用 preseed 自动化安装 Debian；
- 配置默认用户、SSH 公钥、基础工具、cloud-init；
- 将 VM 转换为 PVE 模板；
- 处理国内镜像源与 OpenClash 下的 HTTP/1.1 keep-alive 间歇性卡住问题。

## 适用场景

- 需要可重复、可版本化的 Debian VM 模板；
- 模板需要预装常用工具、SSH key、cloud-init；
- 希望克隆出的 VM 自动根据 VM name 设置 hostname；
- 在国内网络环境下构建，需要默认使用清华/国内源。

## 前置条件

- Proxmox VE 节点可访问，已创建 API token；
- 已上传 Debian netinst ISO 到 PVE 存储（如 `local:iso/debian-13.5.0-amd64-netinst.iso`）；
- 运行 Packer 的机器能访问 PVE API，且能被安装器访问（用于拉取 preseed）；
- 已配置 HashiCorp Vault（或准备用 `*.auto.pkrvars.hcl` 注入凭据）。

## 仓库结构

```
debian/debian-13/
├── debian-13.pkr.hcl              # Packer 主配置
├── debian-13.auto.pkrvars.hcl.example  # 示例变量（凭据、网络）
└── http/
    └── preseed.cfg.tmpl           # preseed 模板（注入密码、SSH key）
```

## 快速开始

### 1. 配置 Vault

创建 `env.sh`（已 gitignore）：

```bash
export VAULT_TOKEN='s.xxxxxxxxxxxxxxx'
export VAULT_ADDR='http://xx.xx.xx.xx:8200'
```

写入 Vault（路径 `secrets/proxmox`）：

```bash
vault kv put secrets/proxmox url="https://pve.example.com:8006/api2/json" username="root@pam!packer" token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 2. 准备本地变量

```bash
cd debian/debian-13
cp debian-13.auto.pkrvars.hcl.example debian-13.auto.pkrvars.hcl
# 编辑 debian-13.auto.pkrvars.hcl：
#   http_host      - Packer 机器 IP，安装器用来下载 preseed
#   ssh_password   - 模板默认用户密码
#   ssh_public_key - 要写入 authorized_keys 的公钥
```

### 3. 构建

```bash
source env.sh
packer init .
packer build .
```

构建完成后，PVE 上会出现 VMID 9000（`debian-13-clean-template`）并自动转换为模板。

## 关键配置说明

### Packer 源配置

- `source "proxmox-iso" "debian_13"` 使用本地 ISO 安装；
- `http_content` 动态渲染 preseed，避免把密码写死到仓库；
- `boot_command` 在启动时把 preseed URL 传给安装器；
- `ssh_username` / `ssh_password` 用于 Packer 在安装完成后登录并标记完成。

### Preseed 模板

`http/preseed.cfg.tmpl` 中：

- 设置 locale、keyboard、时区；
- 磁盘使用 `partman-auto/choose_recipe select atomic`；
- 安装 `standard` + `ssh-server` + 常用工具（`sudo`, `qemu-guest-agent`, `cloud-init`, `curl`, `vim`, `jq` 等）；
- 写入国内源 `/etc/apt/sources.list`；
- 添加 `Acquire::http::Pipeline-Depth "0";` 配置；
- 写入 SSH 公钥、sudo 规则、shell aliases；
- 启用 `cloud-init`，使克隆出的 VM 能根据 VM name 自动设置 hostname。

### Cloud-init 与 hostname

模板中已预装并启用 `cloud-init`。在 PVE 中克隆模板时：

```bash
qm clone 9000 101 --name my-vm --full true
```

`cloud-init` 会在首次启动时把 hostname 设为 `my-vm`。

## 从模板克隆与验证

```bash
# 全量克隆
sudo qm clone 9000 101 --name test-vm --full true
sudo qm start 101

# 获取 IP 后登录
ssh yimeng@<ip>
hostname          # 应为 test-vm
cat /etc/apt/sources.list
sudo apt update
```

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

本模板在 preseed 中已写入：

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
- `preseed.cfg.tmpl` 中密码和公钥通过 Packer 变量在渲染时注入，不会出现在最终仓库中。

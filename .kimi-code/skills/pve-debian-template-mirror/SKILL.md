# PVE Debian 模板国内源切换与网络诊断

## 描述

在 QWRT/OpenWrt + OpenClash 环境下，PVE/VM 访问国内 Debian 镜像（清华、阿里、163 等）可能出现 HTTP/1.1 keep-alive 卡住，但 `HTTP/1.0` / `Connection: close` / `deb.debian.org` 正常的现象。

本 skill 描述如何：
1. 诊断该网络问题；
2. 离线修改 PVE 上已存在的 Debian 模板磁盘，将其 `sources.list` 切换为清华源；
3. 在 Packer 构建阶段直接写入国内源与 apt 防 pipeline 配置。

## 适用场景

- PVE 上创建的 Debian VM/模板需要默认使用国内镜像源；
- `apt-get update` 访问国内源间歇性卡住，但国外源正常；
- 已有模板需要修改 `/etc/apt/sources.list` 而不想重新打包。

## 前置条件

- PVE 节点可登录，且具有 sudo/root 权限；
- 模板磁盘为 LVM thin 卷（如 `local-lvm:base-<vmid>-disk-0`）；
- 路由器（OpenWrt/QWRT）可 SSH 登录查看 iptables/ipset/OpenClash 配置；
- 已安装 `nbd` 内核模块与 `qemu-nbd`。

## 诊断步骤

### 1. 在受影响的机器上复现

```bash
# HTTP/1.1 keep-alive，观察是否卡住
timeout 15 curl -v --http1.1 -o /dev/null -s http://mirrors.tuna.tsinghua.edu.cn/debian/

# 对比 HTTP/1.0 / Connection: close
timeout 15 curl -v --http1.0 -o /dev/null -s http://mirrors.tuna.tsinghua.edu.cn/debian/
timeout 15 curl -v --http1.1 -H "Connection: close" -o /dev/null -s http://mirrors.tuna.tsinghua.edu.cn/debian/

# 对比国外源
timeout 15 curl -v --http1.1 -o /dev/null -s http://deb.debian.org/debian/
```

### 2. 检查 OpenClash 是否 bypass 国内 IP

```bash
# 在路由器上执行
ipset test china_ip_route 101.6.15.130
iptables -t nat -L openclash -v -n
iptables -t nat -L openclash_output -v -n
```

如果目标 IP 在 `china_ip_route` 中，OpenClash 不会把流量重定向到代理端口，可排除 fake-ip/代理问题。

### 3. 验证 apt 实际可用性

即使 `curl --http1.1` 间歇性卡住，`apt` 仍可能正常工作，尤其是加上：

```text
Acquire::http::Pipeline-Depth "0";
```

建议直接测试：

```bash
echo 'deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware' | sudo tee /tmp/tuna.list
sudo apt-get -o Dir::Etc::sourcelist=/tmp/tuna.list -o Dir::Etc::sourceparts=/tmp/empty update
```

## 离线修改已有模板

### 1. 停止所有依赖该模板基础盘的链接克隆

```bash
sudo qm list
sudo qm stop <linked-clone-vmid>
```

### 2. 将模板基础盘置为可写并挂载

```bash
VMID=9000
sudo lvchange -prw /dev/pve/base-${VMID}-disk-0
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 -f raw /dev/pve/base-${VMID}-disk-0
sleep 1
mkdir -p /tmp/mnt-${VMID}
sudo mount /dev/nbd0p1 /tmp/mnt-${VMID}
```

### 3. 修改 sources.list 与 apt 配置

```bash
sudo tee /tmp/mnt-${VMID}/etc/apt/sources.list <<'SRC'
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware
deb http://mirrors.tuna.tsinghua.edu.cn/debian-security/ trixie-security main contrib non-free non-free-firmware
SRC

sudo tee /tmp/mnt-${VMID}/etc/apt/apt.conf.d/99nopipelining <<'APT'
Acquire::http::Pipeline-Depth "0";
APT
```

### 4. 卸载并恢复只读

```bash
sudo umount /tmp/mnt-${VMID}
sudo qemu-nbd -d /dev/nbd0
sudo lvchange -pr /dev/pve/base-${VMID}-disk-0
```

### 5. 重新启动链接克隆并验证

```bash
sudo qm start <linked-clone-vmid>
# 登录后执行
sudo apt-get update
```

## Packer 构建阶段直接写入国内源

在 `http/preseed.cfg` 的 `preseed/late_command` 中写入：

```text
in-target /bin/sh -c "printf '%s\\n' \
  'deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware' \
  'deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware' \
  'deb http://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware' \
  'deb http://mirrors.tuna.tsinghua.edu.cn/debian-security/ trixie-security main contrib non-free non-free-firmware' \
  > /etc/apt/sources.list"; \
in-target /bin/sh -c "printf '%s\\n' 'Acquire::http::Pipeline-Depth \"0\";' > /etc/apt/apt.conf.d/99nopipelining"; \
```

安装阶段 mirror 也改为国内：

```text
d-i mirror/country string manual
d-i mirror/http/hostname string mirrors.tuna.tsinghua.edu.cn
d-i mirror/http/directory string /debian
```

## 已知问题

- `mirrors.163.com` 在该环境下 consistently 卡住，建议避免；
- 间歇性卡住可能和 ISP/路由器转发路径对 HTTP/1.1 keep-alive 的处理有关，非单一配置错误；
- `Acquire::http::Pipeline-Depth "0"` 可降低 apt 触发概率。

## 敏感信息处理

- 不要把 PVE API token、root 密码、SSH 私钥写入仓库；
- 使用 HashiCorp Vault 或环境变量注入 Proxmox 凭据；
- `preseed.cfg` 中的密码和 SSH 公钥应使用变量或占位符。

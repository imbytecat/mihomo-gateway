# Mihomo Gateway

一台机器即可让整个局域网走代理。基于 NixOS + Mihomo + nftables TPROXY 的**单臂透明代理网关**，声明式配置、可复现构建。

- 插在现有网络旁边，不替代主路由
- 客户端只需把默认网关指过来，流量自动按规则走代理
- TPROXY 模式（内核态重定向），比 TUN 性能好
- 两种部署方式任选：丢个 qcow2 镜像 / 远程把一台机器刷成网关

> ⚠️ **这是作者自用 appliance 的开源版本**。`modules/core.nix` 里预置的是作者的 SSH 公钥，自用前请 fork 并改掉，否则你登不进去。

## 部署

先选场景：

| 我想...                              | 用这个         | 一条命令              |
| ------------------------------------ | -------------- | --------------------- |
| 导入 Proxmox / QEMU / Libvirt 直接跑 | qcow2 镜像     | `just build`          |
| 把一台 VPS / 物理机远程刷成网关      | nixos-anywhere | `just install <IP>`   |

### 方式 A：qcow2 镜像

```bash
just build
# → result/mihomo-gateway-<rev>.qcow2  (~500 MB, zstd 压缩)
```

导入任意支持 qcow2 的 Hypervisor。最低要求：

- **UEFI 引导**（Proxmox 选 OVMF；virt-manager 默认即可）
- 内存 ≥ 512 MB
- 一块网卡，能 DHCP 拿到 IP

懒得自己 build？从 [Releases](https://github.com/imbytecat/mihomo-gateway/releases) 下预构建镜像。

### 方式 B：nixos-anywhere 远程刷机

把任意一台已跑 Linux 的机器（VPS、物理机、Live CD 都行）**格式化**后装成网关：

```bash
just install 192.0.2.10
```

前提：

- 能用你本机的 ssh key 以 root 登录目标机
- 目标机硬盘是 `/dev/sda`；不是的话先改 `profiles/disko.nix`：
  ```nix
  diskDevice = "/dev/nvme0n1";   # 或 /dev/vda、/dev/sdb 等
  ```

装完后目标机会重启进新系统，hostname 变成 `mihomo-gateway`。

## 部署后配置

### 1. SSH 登录

```bash
ssh root@<gateway-ip>
```

默认禁用密码登录，仅 key 认证。

### 2. 配置订阅

首次进系统时 mihomo 跑的是内置 fallback（直连模式，没配订阅就不走代理）。写入环境变量文件触发订阅拉取：

```bash
cat > /etc/mihomo/env << 'EOF'
CONFIG_URL=https://your-subscription-url
SECRET=your-api-password
EOF
```

- `CONFIG_URL`：Mihomo / Clash 订阅链接
- `SECRET`：external-controller 的 API 密码（访问 `http://<ip>:9090` 时需要）

写入后会立刻触发 `mihomo-subscribe.service`：下载 → 净化 → 合并 → 验证 → 重启 mihomo。**首次可能花几十秒到几分钟**（Mihomo 首次会下载 geodata / GeoIP / rule provider / dashboard UI），在 `/var/lib/mihomo/` 看到 `.mihomo-config.*.yaml` 临时文件是正常的。

之后每 6 小时自动更新。手动触发：

```bash
systemctl start mihomo-subscribe
journalctl -u mihomo-subscribe -f    # 看进度/报错
```

### 3. 客户端指网关

把需要走代理的设备，默认网关指到 gateway 的 IP 即可。一般两种做法：

- **整网代理**：主路由 DHCP option 把网关推成 gateway 的 IP
- **按需代理**：客户端系统设置里手动改默认网关

> 本网关**不做 DHCP / NAT**，只拦截转发流量。所以不替代主路由，插在主路由旁边即可。

## 更新

两种部署方式都支持就地 rebuild switch：

```bash
# 在 gateway 本机，从 github 拉最新（qcow2 用 #vm，nixos-anywhere 装的用 #bare-metal）
nixos-rebuild switch --flake github:imbytecat/mihomo-gateway#bare-metal

# 或从开发机远程推
just switch 192.0.2.10
```

## 常见问题

**开机后 SSH 连不上 / 没拿到 IP**
`modules/core.nix` 里 networkd 匹配的是 `en* eth*`（覆盖 `eno1` / `ens18` / `enp0s3` / `eth0` 等）。如果你的机器网卡名不在这些里（极少数情况，比如 `wlan0`），改 `matchConfig.Name`。

**订阅拉下来但 mihomo 起不来**
```bash
journalctl -u mihomo -u mihomo-subscribe
```
常见原因：订阅 YAML 被净化后缺字段、`mihomo -t` 跑不过、geodata 下载被墙。净化规则写在 `modules/mihomo.nix` 的 `subscribeScript`。

**想改端口 / fwmark / 策略路由表**
全都集中在 `modules/constants.nix`，改一处就好。

**能不能用 TUN 模式**
不能。TPROXY 是本仓库的核心定位，需要 TUN 的话找别的项目。

**能不能用 IPv6**
转发被 sysctl + nftables 双重阻断，**是故意的**。避免客户端 v6 流量绕过代理。

## 国内用户提速（可选）

`cache.nixos.org` 在国内拉取较慢，`just build` / `install` / `switch` 前建议在本机 `~/.config/nix/nix.conf` 加一条国内镜像：

```
extra-substituters = https://mirror.sjtu.edu.cn/nix-channels/store
```

也可以换成 TUNA、USTC、NJU 任意一个，挑最快的即可。**不建议写进仓库 `flake.nix`**：GitHub Actions 在境外，走 cache.nixos.org 更快，写进去反而拖慢 CI。

## 开发

```bash
just build          # 构建 qcow2
just install HOST   # nixos-anywhere 装到 HOST
just switch  HOST   # rebuild switch 到 HOST
just check          # 构建 vm + bare-metal toplevel 验证
just fmt            # nixfmt 格式化
just update         # 更新 flake inputs
```

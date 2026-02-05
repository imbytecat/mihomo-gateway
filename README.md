# Mihomo Gateway

NixOS VM 透明代理网关，使用 Mihomo + nftables TPROXY。

## 特性

- **TPROXY 模式**: 内核态重定向，比 TUN 性能更好
- **VM 镜像**: raw 格式，支持 Proxmox VE、QEMU/KVM 等平台
- **NixOS Flakes**: 声明式配置，可复现构建
- **生产级加固**: 原子更新、systemd 沙箱、自动重启
- **IPv6 安全**: 阻断 IPv6 转发，防止流量绕过代理

## 快速开始

```bash
nix build .#image  # 构建 VM 镜像
```

输出位于 `./result/` (raw 格式)

## Proxmox VE 部署

### 1. 导入镜像

```bash
# 解压 (如果是压缩版本)
zstd -d mihomo-gateway.raw.zst

# 创建 VM
qm create 100 --name mihomo-gateway --memory 512 --cores 1 --net0 virtio,bridge=vmbr0

# 导入磁盘
qm importdisk 100 mihomo-gateway.raw local-lvm

# 配置 VM (UEFI 启动)
qm set 100 --virtio0 local-lvm:vm-100-disk-0
qm set 100 --boot order=virtio0
qm set 100 --bios ovmf
qm set 100 --efidisk0 local-lvm:1,format=raw,efitype=4m,pre-enrolled-keys=0
qm set 100 --serial0 socket --vga serial0

# 启动
qm start 100
```

### 2. 配置订阅

SSH 登录后创建环境变量文件：

```bash
cat > /etc/mihomo/mihomo.env << 'EOF'
SUBSCRIPTION_URL=https://your-subscription-url
SECRET=your-api-secret
EOF
chmod 600 /etc/mihomo/mihomo.env
```

| 变量               | 必需 | 说明                                    |
| ------------------ | ---- | --------------------------------------- |
| `SUBSCRIPTION_URL` | 是   | 订阅地址                                |
| `SECRET`           | 否   | API 密钥，用于 Dashboard/external-controller 认证 |

### 服务说明

| 服务                       | 类型   | 作用                         |
| -------------------------- | ------ | ---------------------------- |
| `mihomo.service`           | 常驻   | 运行 Mihomo 代理             |
| `mihomo-subscribe.service` | oneshot | 拉取订阅、验证、替换配置     |
| `mihomo-subscribe.timer`   | timer  | 定时触发订阅拉取             |

**启动流程**：
1. 系统启动 → mihomo 使用现有配置启动
2. 2 分钟后 → timer 触发 subscribe 拉取订阅
3. 订阅验证通过 → 替换配置并重启 mihomo
4. 之后每 6 小时自动更新

手动操作：

```bash
systemctl start mihomo-subscribe   # 立即拉取订阅
systemctl status mihomo            # 查看代理状态
journalctl -u mihomo-subscribe     # 查看订阅拉取日志
```

### 订阅配置说明

拉取的订阅会自动注入以下配置（覆盖订阅原有值）：

```yaml
tproxy-port: 7894
routing-mark: 6666
allow-lan: true
find-process-mode: "off"
ipv6: false
dns.ipv6: false
secret: <从 SECRET 环境变量读取>
```

配置会在应用前用 `mihomo -t` 验证，验证失败则保留原配置。

## 命令

```bash
nix build .#image    # 构建 VM 镜像
nix build .#default  # 构建系统配置
nix develop          # 开发 shell
nix fmt              # 格式化代码
nix flake check      # 检查 flake
nix flake update     # 更新依赖
rm -rf result        # 清理输出
```

## 目录结构

```
mihomo-gateway/
├── flake.nix              # Flake 入口
├── flake.lock             # 版本锁定
├── configuration.nix      # NixOS 配置
└── modules/
    ├── constants.nix      # 共享常量 (端口、标记等)
    ├── tproxy.nix         # TPROXY 网络层 (sysctl + routing + nftables)
    └── mihomo.nix         # Mihomo 服务 + 订阅管理
```

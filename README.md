# Mihomo Gateway

NixOS LXC 透明代理网关，使用 Mihomo + nftables TPROXY。

## 特性

- **TPROXY 模式**: 内核态重定向，比 TUN 性能更好
- **LXC 容器**: 无需特权构建，CI 友好
- **NixOS Flakes**: 可复现构建

## 环境准备

### Windows (WSL2)

```powershell
wsl --install --no-distribution
# 下载 https://github.com/nix-community/NixOS-WSL/releases
wsl --import NixOS $env:LOCALAPPDATA\WSL\NixOS .\nixos-wsl.tar.gz
wsl -d NixOS
```

### Linux / macOS

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh
```

### Arch Linux

```bash
sudo pacman -S nix
sudo systemctl enable --now nix-daemon
sudo usermod -aG nixbld $USER
# 重新登录后启用 Flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

## 快速开始

```bash
nix develop          # 进入开发 shell (包含 task)
task tarball         # 构建 LXC tarball
```

输出位于 `./result/tarball/*.tar.xz`

## 部署

1. 将 tarball 导入 Proxmox VE 或其他 LXC 平台
2. 配置订阅 URL（见下方）
3. 启动容器

### 配置订阅

创建环境变量文件：

```bash
echo 'SUBSCRIPTION_URL=https://your-subscription-url' > /etc/mihomo/mihomo.env
chmod 600 /etc/mihomo/mihomo.env
```

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

拉取的订阅会自动注入以下 TPROXY 必需配置（覆盖订阅原有值）：

```yaml
tproxy-port: 7894
routing-mark: 6666
allow-lan: true
find-process-mode: "off"
```

配置会在应用前用 `mihomo -t` 验证，验证失败则保留原配置。

## 命令

```bash
task --list          # 所有命令
task build           # 构建系统配置
task tarball         # 构建 LXC tarball
task dev             # 开发 shell
task fmt             # 格式化代码
task check           # 检查 flake
task update          # 更新依赖
task clean           # 清理输出

# 原生 nix 命令
nix fmt              # 格式化
nix flake check      # 验证构建
```

## 目录结构

```
mihomo-gateway/
├── flake.nix           # Flake 入口
├── flake.lock          # 版本锁定
├── configuration.nix   # NixOS 配置
├── mihomo.nix          # Mihomo TPROXY 模块
└── Taskfile.yml        # 构建任务
```

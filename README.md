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
mise install         # 安装 task
task tarball         # 构建 LXC tarball
```

输出位于 `./result/tarball/*.tar.xz`

## 部署

1. 将 tarball 导入 Proxmox VE 或其他 LXC 平台
2. 编辑 `/etc/mihomo/config.yaml` 配置代理
3. `systemctl restart mihomo`

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
├── Taskfile.yml        # 构建任务
└── mise.toml           # 工具版本
```

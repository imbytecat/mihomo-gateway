# IaC - Infrastructure as Code

个人 IaC 仓库，使用 **NixOS Flakes** 构建 LXC 容器镜像。

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
# 重新登录

# 启用 Flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

## 快速开始

```bash
mise install                    # 安装 task
task gateway:build              # 构建系统配置
task gateway:tarball            # 构建 LXC tarball
```

## NixOS 主机

### mihomo-gateway

透明代理网关，使用 Mihomo + nftables TPROXY。

- **TPROXY 模式**: 比 TUN 性能更好 (内核态重定向)
- **LXC 容器**: 无需特权即可构建，CI 友好

部署后编辑 `/etc/mihomo/config.yaml`，然后 `systemctl restart mihomo`。

## 命令

```bash
task --list                     # 所有命令
task dev                        # 进入开发 shell
task fmt                        # 格式化 Nix 代码
task check                      # 检查 flake
task update                     # 更新依赖
task clean                      # 清理构建输出

# 也可以直接使用 nix 命令
nix fmt                         # 格式化 (使用 nixfmt-rfc-style)
nix flake check                 # 验证构建
```

## 目录结构

```
iac/
├── flake.nix                   # Flake 入口
├── flake.lock                  # 版本锁定
├── hosts/                      # NixOS 主机配置
│   └── mihomo-gateway/
├── Taskfile.yml
└── mise.toml
```

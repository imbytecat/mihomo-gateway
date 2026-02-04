# AGENTS.md - AI Coding Agent Guidelines

> 本文档为 AI 编码代理提供项目指南。

## 项目概述

个人 IaC (Infrastructure as Code) 仓库，使用 **NixOS Flakes** 管理：
- **NixOS 主机配置**: VM 镜像 (输出 raw/qcow2)
- **Docker Compose**: 容器化服务 (计划中)
- **Terraform/OpenTofu**: 基础设施编排 (计划中)

## 工具链

通过 `mise` 管理工具版本：
```toml
[tools]
task = 'latest'

[env]
_.file = ".env"
```

NixOS 构建需要 Nix，可在 Linux/macOS/WSL2 运行。

## 构建命令

所有命令通过 [Taskfile](https://taskfile.dev) 执行：

```bash
# 查看所有可用任务
task --list

# 构建 mihomo-gateway
task gateway:build       # 构建系统配置
task gateway:image       # 构建磁盘镜像

# 开发
task dev                 # 进入开发 shell
task fmt                 # 格式化 Nix 代码
task check               # 检查 flake 配置
task update              # 更新 flake.lock

# 清理
task clean               # 清理构建输出
task list                # 列出所有配置
```

## 目录结构

```
iac/
├── flake.nix                 # Flake 入口
├── flake.lock                # 版本锁定
├── Taskfile.yml              # 构建任务
├── mise.toml                 # 工具版本
├── hosts/                    # NixOS 主机配置
│   └── mihomo-gateway/       # 透明代理网关
│       ├── default.nix       # 主机配置
│       └── mihomo.nix        # Mihomo TPROXY 模块
└── docker/                   # Docker Compose 服务 (TODO)
```

**关键原则**: 每个主机配置都是**自包含**的。

## 代码风格

### Nix

- 使用 `nixfmt-rfc-style` 格式化
- 模块化：每个功能一个 `.nix` 文件
- 使用 `let ... in` 定义局部变量

### nftables

- 使用 `inet` 族
- 使用 `set` 定义地址集合

## 添加新主机

1. 创建目录: `mkdir -p hosts/new-host`

2. 创建 `hosts/new-host/default.nix`

3. 在 `flake.nix` 添加配置:
   ```nix
   nixosConfigurations.new-host = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     modules = [ ./hosts/new-host ];
   };
   ```

4. 构建: `nix build .#nixosConfigurations.new-host.config.system.build.toplevel`

## Commit 规范

使用 Conventional Commits，中文描述：

```
feat(nixos): 添加新主机配置
fix(mihomo): 修复 nftables 规则
docs: 更新 README
```

## 注意事项

### NixOS 构建

- 需要 Nix (Linux/macOS/WSL2)
- Windows 用户使用 WSL2 + NixOS-WSL
- `flake.lock` 锁定所有依赖版本，确保可复现

### TPROXY 透明代理

- 需要 `CAP_NET_ADMIN`, `CAP_NET_RAW`, `CAP_NET_BIND_SERVICE`
- `routing-mark` 必须与 nftables bypass 规则匹配
- `rp_filter=0` 是必需的
- 比 TUN 模式性能更好 (内核态直接重定向)

### 调试

```bash
# 检查配置语法
nix flake check

# 进入开发 shell (包含 nil, nixfmt)
nix develop

# 只构建不输出镜像
nix build .#nixosConfigurations.mihomo-gateway.config.system.build.toplevel
```

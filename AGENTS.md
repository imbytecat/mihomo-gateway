# AGENTS.md - AI Coding Agent Guidelines

> 本文档为 AI 编码代理提供项目指南。

## 项目概述

**Mihomo Gateway** - 使用 NixOS Flakes 构建的透明代理网关 LXC 镜像。

- 使用 Mihomo + nftables TPROXY
- 输出 LXC tarball，用于 Proxmox VE 等平台

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

## 代码风格

### Nix

- 使用 `nixfmt` 格式化 (RFC style)
- 模块化：每个功能一个 `.nix` 文件
- 使用 `let ... in` 定义局部变量

### nftables

- 使用 `inet` 族
- 使用 `set` 定义地址集合

## Commit 规范

使用 Conventional Commits，中文描述：

```
feat: 添加新功能
fix: 修复问题
docs: 更新文档
refactor: 重构代码
chore: 杂项维护
```

## 注意事项

### NixOS 构建

- 需要 Nix (Linux/macOS/WSL2)
- Windows 用户使用 WSL2
- `flake.lock` 锁定依赖版本，确保可复现
- **无需特权**: LXC tarball 构建不需要 root 或 KVM

### TPROXY 透明代理

- 需要 `CAP_NET_ADMIN`, `CAP_NET_RAW`, `CAP_NET_BIND_SERVICE`
- `routing-mark` 必须与 nftables bypass 规则匹配
- `rp_filter=0` 是必需的
- 比 TUN 模式性能更好 (内核态直接重定向)

### 调试

```bash
nix flake check      # 检查配置语法
nix develop          # 进入开发 shell
nix build .#default  # 只构建不输出镜像
```

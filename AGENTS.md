# AGENTS.md - AI Coding Agent Guidelines

> 本文档为 AI 编码代理提供项目指南。

## 项目概述

个人 IaC (Infrastructure as Code) 仓库，用于管理：
- **mkosi**: VM 镜像 (Debian 基础，输出 raw/qcow2)
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

mkosi 需要在 Linux/WSL2 环境运行。

## 构建命令

所有命令通过 [Taskfile](https://taskfile.dev) 执行：

```bash
# 查看所有可用任务
task --list

# mihomo-gateway 模板专用命令
task gateway:download    # 预下载 mihomo 二进制
task gateway:build       # 构建镜像 (需要 Linux/WSL2)
task gateway:clean       # 清理构建输出

# 清理
task clean              # 清理所有构建输出
task list               # 列出所有模板
```

## 目录结构

```
iac/
├── Taskfile.yml              # 统一构建入口
├── mise.toml                 # 工具版本 + .env 自动加载
├── mkosi/                    # VM 镜像
│   └── <template-name>/      # 每个模板自包含
│       ├── mkosi.conf        # mkosi 配置
│       ├── mkosi.postinst    # 安装后脚本
│       ├── mkosi.extra/      # 要复制到镜像的文件
│       └── download-*.sh     # 预下载脚本
└── docker/                   # Docker Compose 服务 (TODO)
```

**关键原则**: 每个 VM 模板都是**自包含**的。

## 代码风格

### mkosi 配置

- INI 格式
- 使用 `mkosi.extra/` 目录结构镜像目标文件系统

### Shell 脚本

- 首行: `#!/bin/bash`
- 启用严格模式: `set -euo pipefail`
- 使用 `echo "==> Step"` 记录进度

### nftables

- 使用 `inet` 族
- 使用 `set` 定义地址集合

## 添加新 VM 模板

1. 复制现有模板目录:
   ```bash
   cp -r mkosi/mihomo-gateway mkosi/new-template
   ```

2. 修改 `mkosi.conf` 和配置文件

3. 构建: `task gateway:build` (在 WSL2 中)

## Commit 规范

使用 Conventional Commits，中文描述：

```
feat(mkosi): 添加新 VM 模板
fix(scripts): 修复安装脚本
docs: 更新 README
```

## 注意事项

### mkosi 构建

- 需要 Linux 或 WSL2
- 可在 Gitea Actions (Linux runner) 中运行
- 输出 raw 格式，可用 qemu-img 转换为 qcow2

### TPROXY 透明代理

- 需要 `CAP_NET_ADMIN`, `CAP_NET_RAW`, `CAP_NET_BIND_SERVICE`
- `routing-mark` 必须与 nftables bypass 规则匹配
- `rp_filter=0` 是必需的

### 调试

```bash
# 在 WSL2 中
cd mkosi/mihomo-gateway
mkosi -f build  # 强制重建
```

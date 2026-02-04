# AGENTS.md - AI Coding Agent Guidelines

> 本文档为 AI 编码代理提供项目指南。

## 项目概述

个人 IaC (Infrastructure as Code) 仓库，用于管理：
- **Packer**: Proxmox VE 虚拟机模板
- **Docker Compose**: 容器化服务 (计划中)
- **Terraform/OpenTofu**: 基础设施编排 (计划中)

## 工具链

通过 `mise` 管理工具版本：
```toml
[tools]
packer = 'latest'
task = 'latest'
```

## 构建命令

所有命令通过 [Taskfile](https://taskfile.dev) 执行：

```bash
# 查看所有可用任务
task --list

# mihomo-gateway 模板专用命令
task gateway:init       # 初始化 Packer 插件
task gateway:fmt        # 格式化 HCL 文件
task gateway:validate   # 验证模板
task gateway:build      # 构建 VM 模板
task gateway:build-debug # 调试模式构建

# 通用 Packer 命令 (用于任意模板)
task packer:init TEMPLATE=mihomo-gateway
task packer:validate TEMPLATE=mihomo-gateway
task packer:build TEMPLATE=mihomo-gateway

# 清理
task clean              # 清理 Packer 缓存
task list-templates     # 列出所有模板
```

## 目录结构

```
iac/
├── Taskfile.yml              # 统一构建入口
├── .env.example              # 环境变量模板
├── packer/proxmox/           # Proxmox VM 模板
│   └── <template-name>/      # 每个模板自包含
│       ├── *.pkr.hcl         # Packer 模板定义
│       ├── variables.pkr.hcl # 变量声明
│       ├── http/             # Preseed/Cloud-Init
│       ├── scripts/          # 配置脚本
│       └── files/            # 配置文件
└── docker/                   # Docker Compose 服务 (TODO)
```

**关键原则**: 每个 VM 模板都是**自包含**的，所有相关配置都在同一目录下。

## 代码风格

### HCL (Packer/Terraform)

- 使用 `packer fmt` 格式化
- 变量使用 `snake_case`
- 敏感变量标记 `sensitive = true`
- 必须包含 `description` 字段
- 使用 `locals` 避免重复

```hcl
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}
```

### Shell 脚本

- 首行: `#!/bin/bash`
- 启用严格模式: `set -euo pipefail`
- 使用 `echo "==> Step description"` 记录进度
- 变量使用 `${VAR}` 或 `"$VAR"` 带引号
- 检查文件存在: `if [ -f /path/to/file ]; then`

```bash
#!/bin/bash
set -euo pipefail

echo "==> Installing package..."
apt-get update && apt-get install -y package-name
echo "==> Done!"
```

### YAML (Taskfile, Configs)

- 2 空格缩进
- 使用引号包裹包含特殊字符的字符串
- 注释以 `#` 开头，前面留空行

### nftables

- 使用 `inet` 族 (同时支持 IPv4/IPv6)
- 使用 `set` 定义地址集合
- 使用 `chain` 按功能分组规则

## 环境变量

Packer 变量通过 `PKR_VAR_` 前缀传递：

```bash
export PKR_VAR_proxmox_api_url="https://pve:8006/api2/json"
export PKR_VAR_proxmox_api_token_id="root@pam!packer"
export PKR_VAR_proxmox_api_token_secret="xxx"
```

**永远不要提交**:
- `.env` 文件
- API Token/Secret
- SSH 私钥
- 任何凭据

## 添加新 VM 模板

1. 复制现有模板目录:
   ```bash
   cp -r packer/proxmox/mihomo-gateway packer/proxmox/new-template
   ```

2. 修改 `new-template/*.pkr.hcl`

3. 可选: 在 `Taskfile.yml` 添加专用 task

4. 构建: `task packer:build TEMPLATE=new-template`

## Commit 规范

使用 Conventional Commits，中文描述：

```
feat(packer): 添加新 VM 模板
fix(scripts): 修复 mihomo 安装脚本
docs: 更新 README
chore: 清理无用文件
```

## 注意事项

### Packer for Proxmox

- `boot_command` 通过 VNC 发送键盘输入，对延迟敏感
- 使用 `ssh_handshake_attempts = 100` 应对慢速安装
- 模板完成后会自动清理 SSH host keys 和 machine-id

### TPROXY 透明代理

- 需要 `CAP_NET_ADMIN`, `CAP_NET_RAW`, `CAP_NET_BIND_SERVICE`
- `routing-mark` 必须与 nftables bypass 规则匹配
- `rp_filter=0` 是必需的，否则回包会被丢弃

### 调试

```bash
# Packer 调试输出
PACKER_LOG=1 task gateway:build

# 或使用 debug 任务
task gateway:build-debug
```

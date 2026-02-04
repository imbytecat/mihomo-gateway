# IaC - Infrastructure as Code

个人基础设施即代码仓库，用于管理 Proxmox VE 虚拟机模板、Docker Compose 服务等。

## 项目结构

```
iac/
├── Taskfile.yml                          # 统一构建入口
├── mise.toml                             # 工具版本管理
├── scripts/                              # 全局脚本
│   └── import-to-proxmox.sh              # 导入 qcow2 到 Proxmox
├── packer/proxmox/                       # Proxmox VM 模板
│   └── mihomo-gateway/                   # 透明代理网关 (自包含)
│       ├── *.pkr.hcl                     # Packer 模板
│       ├── http/                         # Preseed 配置
│       ├── scripts/                      # 配置脚本
│       └── files/                        # 配置文件
└── docker/                               # Docker Compose 服务 (TODO)
```

每个 VM 模板都是**自包含**的，所有相关配置都在同一目录下，便于维护。

## 前置要求

使用 [mise](https://mise.jdx.dev/) 管理工具版本和环境变量：

```bash
mise install  # 安装 packer, task
```

## 构建模式

支持两种构建模式，适应不同网络环境：

| 模式 | 命令 | 场景 |
|------|------|------|
| **本地构建** | `task gateway:build-local` | CI/有网络环境，生成 qcow2 |
| **直接构建** | `task gateway:build` | 可连接 Proxmox API |

### 模式 1: 本地构建 (推荐用于 CI/CD)

```bash
# 1. 预下载 Mihomo 二进制 (在有网络的环境)
task gateway:download-mihomo

# 2. 本地构建 qcow2 镜像
task gateway:build-local

# 3. 将镜像传输到 Proxmox
scp output-mihomo-gateway/mihomo-gateway.qcow2 root@pve:/tmp/

# 4. 在 Proxmox 上导入
ssh root@pve 'bash -s' < scripts/import-to-proxmox.sh
```

### 模式 2: 直接在 Proxmox 构建

```bash
# 设置环境变量 (或复制 .env.example 为 .env)
cp .env.example .env
vim .env  # 填入 Proxmox API 凭据

# 构建
task gateway:build
```

## VM 模板

### mihomo-gateway

透明代理网关 VM，基于 Debian 12，预装:

- **Mihomo** (Clash Meta) TPROXY 透明代理
- **nftables** 流量拦截规则
- **策略路由** 配置
- **Cloud-Init** 支持

#### 技术规格

| 配置项 | 值 |
|--------|-----|
| TPROXY 端口 | 7894 |
| Routing Mark | 6666 |
| DNS (Fake-IP) | 198.18.0.1/16 |
| vCPU | 2 |
| 内存 | 512MB |
| 磁盘 | 16GB |

#### 部署后配置

```bash
# SSH 进入 VM 后
sudo vim /etc/mihomo/config.yaml

# 添加你的代理服务器到 proxies 部分
# 配置 proxy-groups 和 rules

# 启动服务
sudo systemctl start mihomo

# 查看状态
sudo systemctl status mihomo
sudo nft list tables
```

## 常用命令

```bash
# 查看所有可用任务
task --list

# mihomo-gateway 相关
task gateway:init            # 初始化 Packer 插件
task gateway:validate        # 验证模板
task gateway:build           # 直接在 Proxmox 构建
task gateway:build-local     # 本地 QEMU 构建 (生成 qcow2)
task gateway:download-mihomo # 预下载 Mihomo 二进制

# 通用
task clean                   # 清理缓存和构建输出
task list-templates          # 列出所有模板
```

## 添加新模板

1. 复制现有模板目录:
   ```bash
   cp -r packer/proxmox/mihomo-gateway packer/proxmox/new-template
   ```

2. 修改 `new-template/*.pkr.hcl`

3. 在 `Taskfile.yml` 添加专用 task (可选)

4. 构建:
   ```bash
   task packer:build TEMPLATE=new-template
   ```

## 故障排除

### 构建失败

```bash
# 启用调试输出
task gateway:build-debug

# 或
PACKER_LOG=1 task gateway:build
```

### QEMU 构建问题

确保安装了 QEMU/KVM:
```bash
# Linux
sudo apt install qemu-kvm

# macOS
brew install qemu
```

### 无法访问 GitHub

使用预下载模式:
```bash
# 在有网络的机器上
task gateway:download-mihomo

# 二进制文件保存在 files/mihomo/mihomo-linux-amd64
# 构建时会自动使用本地文件
```

## License

MIT

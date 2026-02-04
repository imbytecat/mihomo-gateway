# IaC - Infrastructure as Code

个人基础设施即代码仓库，用于管理 Proxmox VE 虚拟机模板、Docker Compose 服务等。

## 项目结构

```
iac/
├── Taskfile.yml              # 统一构建入口
├── packer/
│   └── proxmox/              # Proxmox VM 模板
│       └── debian-gateway/   # 透明代理网关 (自包含)
│           ├── *.pkr.hcl     # Packer 模板
│           ├── http/         # Preseed 配置
│           ├── scripts/      # 配置脚本
│           └── files/        # 配置文件
├── shared/                   # 跨模板复用资源
└── docker/                   # Docker Compose 服务 (TODO)
```

每个 VM 模板都是**自包含**的，所有相关配置都在同一目录下，便于维护。

## 前置要求

### 本地环境

- [Packer](https://developer.hashicorp.com/packer/downloads) >= 1.10.0
- [Task](https://taskfile.dev/installation/) (Taskfile runner)

### Proxmox VE

1. 创建 API Token:
   ```bash
   # 在 Proxmox 上执行
   pveum user token add root@pam packer --privsep=0
   ```

2. 下载 Debian ISO 到 Proxmox:
   ```bash
   # 在 Proxmox 上执行
   cd /var/lib/vz/template/iso/
   wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso
   ```

## 快速开始

### 1. 设置环境变量

```powershell
# Windows PowerShell
$env:PKR_VAR_proxmox_api_url = "https://your-proxmox:8006/api2/json"
$env:PKR_VAR_proxmox_api_token_id = "root@pam!packer"
$env:PKR_VAR_proxmox_api_token_secret = "your-token-secret"
$env:PKR_VAR_proxmox_node = "pve"
$env:PKR_VAR_proxmox_iso_file = "local:iso/debian-12.8.0-amd64-netinst.iso"
$env:PKR_VAR_ssh_password = "packer"  # 构建时使用，模板不保留
```

```bash
# Linux/macOS
export PKR_VAR_proxmox_api_url="https://your-proxmox:8006/api2/json"
export PKR_VAR_proxmox_api_token_id="root@pam!packer"
export PKR_VAR_proxmox_api_token_secret="your-token-secret"
export PKR_VAR_proxmox_node="pve"
export PKR_VAR_proxmox_iso_file="local:iso/debian-12.8.0-amd64-netinst.iso"
export PKR_VAR_ssh_password="packer"
```

### 2. 构建模板

```bash
# 查看可用任务
task --list

# 构建 debian-gateway 模板
task gateway:build

# 或使用通用命令
task packer:build TEMPLATE=debian-gateway
```

### 3. 部署 VM

1. 在 Proxmox 中从模板克隆 VM
2. 配置 Cloud-Init (网络、SSH 密钥等)
3. 编辑 `/etc/mihomo/config.yaml` 添加你的代理配置
4. 启动 mihomo 服务: `sudo systemctl start mihomo`

## VM 模板

### debian-gateway

透明代理网关 VM，基于 Debian 12，预装:

- **Mihomo** (Clash Meta) 透明代理
- **nftables** TPROXY 规则
- **策略路由** 配置
- **Cloud-Init** 支持

#### 配置要点

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

## 添加新模板

1. 复制现有模板目录作为基础:
   ```bash
   cp -r packer/proxmox/debian-gateway packer/proxmox/your-new-template
   ```

2. 修改 `your-new-template/*.pkr.hcl` 中的配置

3. 在 `Taskfile.yml` 中添加对应的 task (可选，或使用通用命令)

4. 构建:
   ```bash
   task packer:build TEMPLATE=your-new-template
   ```

## 故障排除

### 构建失败

```bash
# 启用调试输出
task gateway:build-debug

# 或
PACKER_LOG=1 task gateway:build
```

### VNC 连接问题

如果 `boot_command` 失败，检查:
- Proxmox 防火墙是否允许 VNC 端口 (5900-5999)
- 网络延迟是否过高

### TLS 证书问题

如果 Proxmox 使用自签名证书:
```bash
export PKR_VAR_proxmox_skip_tls_verify=true
```

## License

MIT

# IaC - Infrastructure as Code

个人 IaC 仓库，管理 Proxmox VE 虚拟机模板。

## 快速开始

```bash
mise install                    # 安装工具 (packer, task)
cp .env.example .env            # 配置 Proxmox API
task gateway:build              # 构建 mihomo-gateway 模板
```

## VM 模板

### mihomo-gateway

Debian 12 透明代理网关，预装 Mihomo + nftables TPROXY。

```bash
# 离线构建 (CI 用)
task gateway:download-mihomo    # 预下载二进制
task gateway:build-local        # 生成 qcow2

# 在线构建 (直连 Proxmox)
task gateway:build
```

部署后编辑 `/etc/mihomo/config.yaml` 添加代理配置，然后 `systemctl start mihomo`。

## 命令

```bash
task --list                     # 所有命令
task gateway:validate           # 验证模板
task clean                      # 清理缓存
```

## License

MIT

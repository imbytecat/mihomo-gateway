# IaC - Infrastructure as Code

个人 IaC 仓库，使用 mkosi 构建 VM 镜像。

## 快速开始

```bash
mise install                    # 安装工具
task gateway:download           # 下载 mihomo
task gateway:build              # 构建 (需要 Linux/WSL2)
```

## VM 模板

### mihomo-gateway

Debian 12 透明代理网关，预装 Mihomo + nftables TPROXY。

部署后编辑 `/etc/mihomo/config.yaml`，然后 `systemctl restart mihomo`。

## 命令

```bash
task --list                     # 所有命令
task clean                      # 清理
```

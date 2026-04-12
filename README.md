# Mihomo Gateway

NixOS VM 透明代理网关，使用 Mihomo + nftables TPROXY。

## 特性

- **TPROXY 模式**: 内核态重定向，比 TUN 性能更好
- **VM 镜像**: qcow2 格式，支持 QEMU/KVM、Proxmox VE、Libvirt 等
- **NixOS Flakes**: 声明式配置，可复现构建

## 部署

### 1. 导入镜像

使用任意支持 qcow2 的虚拟化平台导入镜像，配置要求：
- UEFI 启动 (OVMF)
- 至少 512MB 内存
- 一个网卡

### 2. 配置订阅

SSH 登录后创建环境变量文件，订阅会自动拉取：

```bash
cat > /etc/mihomo/env << 'EOF'
CONFIG_URL=https://your-config-url
SECRET=your-api-secret
EOF
```

之后每 6 小时自动更新。手动触发：`systemctl start mihomo-subscribe`

### 3. 配置客户端

将客户端默认网关指向此 VM 的 IP 地址。

> 这是一个**单臂透明代理节点**，不是路由器——不内建 DHCP/NAT，只拦截转发流量。

## 开发

所有 flake 输出仅 `x86_64-linux`。

```bash
nix develop       # 开发环境 (just, nixd, nixfmt)
just build        # 构建 VM 镜像 (qcow2)
just check        # 检查 flake
just fmt           # 格式化
```

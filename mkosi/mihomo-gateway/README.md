# Mihomo Gateway (mkosi)

基于 Debian 12 的透明代理网关 VM 镜像。

## 构建

```bash
# 1. 下载 Mihomo (需要网络)
./download-mihomo.sh

# 2. 构建镜像 (需要 Linux/WSL2)
mkosi build

# 输出: output/mihomo-gateway.raw
```

## CI 构建 (Gitea Actions)

```yaml
- uses: systemd/mkosi@main
- run: |
    cd mkosi/mihomo-gateway
    ./download-mihomo.sh
    mkosi build
- uses: actions/upload-artifact@v4
  with:
    name: mihomo-gateway
    path: mkosi/mihomo-gateway/output/
```

## 部署

```bash
# 转换为 qcow2 (可选)
qemu-img convert -f raw -O qcow2 output/mihomo-gateway.raw mihomo-gateway.qcow2

# 上传到 Proxmox 并导入
qm importdisk <vmid> mihomo-gateway.qcow2 <storage>
```

## 配置

启动后编辑 `/etc/mihomo/config.yaml` 添加代理配置，然后:

```bash
systemctl restart mihomo
```

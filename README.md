# Mihomo Gateway

一个 NixOS module，把任意一台机器变成**单臂透明代理网关**：Mihomo + nftables TPROXY，声明式配置、可复现构建。

- 不替代主路由，插在现有网络旁边
- 客户端默认网关指过来即可，流量按 Mihomo 规则走代理
- TPROXY 内核态重定向，比 TUN 性能好

## 使用

在你的 flake 里加 input，然后在某台 host 的配置里 import：

```nix
# flake.nix
{
  inputs.mihomo-gateway.url = "github:imbytecat/mihomo-gateway";

  outputs = { self, nixpkgs, mihomo-gateway, ... }: {
    nixosConfigurations.gateway = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        mihomo-gateway.nixosModules.default
        ./hosts/gateway   # 你自己的 host 配置
      ];
    };
  };
}
```

## Host 必须提供

本 module 只管 mihomo / nftables / 单臂 networking / resolved 这些**网关业务**。
host 必须自己配这些**部署相关**的东西：

- `networking.hostName`
- `boot.loader.*`、`fileSystems.*`（或用 disko）
- `system.stateVersion`
- `services.openssh` + `users.users.<your-user>.openssh.authorizedKeys.keys`
- `time.timeZone`、`i18n.*`
- `nix.settings.*`（experimental-features、substituters 等）

例：

```nix
# hosts/gateway/default.nix
{
  networking.hostName = "mihomo-gateway";
  time.timeZone = "Asia/Shanghai";
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

## 部署后配置

### 1. 写订阅环境变量

首次进系统时 mihomo 跑的是内置 fallback（直连模式）。写入环境变量文件触发订阅拉取：

```bash
cat > /etc/mihomo/env << 'EOF'
CONFIG_URL=https://your-subscription-url
SECRET=your-api-password
EOF
```

- `CONFIG_URL`：Mihomo / Clash 订阅链接
- `SECRET`：external-controller (`:9090`) 的 API 密码

写入后立刻触发 `mihomo-subscribe.service`：下载 → 净化 → 合并 → 验证 → 重启 mihomo。**首次可能花几十秒到几分钟**（首次会下载 geodata / GeoIP / rule provider / dashboard）。

之后每 6 小时自动更新。手动触发：

```bash
systemctl start mihomo-subscribe
journalctl -u mihomo-subscribe -f
```

### 2. 客户端指网关

把需要走代理的设备默认网关指到本机 IP。两种做法：

- **整网代理**：主路由 DHCP 把网关推成本机 IP
- **按需代理**：客户端系统设置里手动改默认网关

> 本 module **不做 DHCP / NAT**，只拦截转发流量。

## 常用常量

集中在 `modules/constants.nix`：

| 常量 | 默认 | 用途 |
|------|------|------|
| `tproxyPort` | 7894 | TPROXY 监听 |
| `mixedPort` | 7890 | HTTP+SOCKS5 混合代理 |
| `dnsPort` | 1053 | Mihomo DNS |
| `routingMark` | 6666 | fwmark |
| `routingTable` | 100 | 策略路由表 |

## 常见问题

**开机后 SSH 连不上 / 没拿到 IP**
`modules/default.nix` 里 networkd 匹配 `en* eth*`（覆盖 `eno1` / `ens18` / `enp0s3` / `eth0` 等）。如果你的网卡名不在这些里（比如 `wlan0`），自己在 host 里 `mkForce` 改 `matchConfig.Name`。

**订阅拉下来但 mihomo 起不来**

```bash
journalctl -u mihomo -u mihomo-subscribe
```

常见原因：订阅 YAML 被净化后缺字段、`mihomo -t` 跑不过、geodata 下载被墙。净化规则在 `modules/mihomo.nix` 的 `subscribeScript`。

**能不能用 TUN 模式 / IPv6**
不能。TPROXY 是核心定位，IPv6 转发被 sysctl + nftables 双重阻断（防止客户端 v6 流量绕过代理），都是有意为之。

## 开发

```bash
nix flake check    # 用最小 host evaluate module
nix fmt            # nixfmt 格式化
nix flake update   # 更新 inputs
```

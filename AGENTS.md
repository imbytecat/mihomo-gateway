# AGENTS.md

NixOS VM 透明代理网关（Mihomo + nftables TPROXY）。输出 qcow2 镜像。

## 命令

```bash
nix fmt                       # nixfmt (RFC style)
nix flake check               # 语法 + 类型检查 (macOS 加 --no-build)
nix build .#default           # 构建系统配置
nix build .#image             # 构建 VM 镜像 (qcow2)
nix develop                   # 开发 shell (nil, nixfmt)
```

无测试套件。验证手段是 `nix flake check`。

## 架构约束

- **单臂代理**：只拦截 transit（转发）流量，不代理本机 OUTPUT。**不要加 OUTPUT 链**。
- **Appliance 模式**：VM 内 `nix.enable = false`，无法在目标机上运行 Nix。
- **`firewall.enable = false`** 是有意的，nftables 规则由 `tproxy.nix` 直接管理。
- **`external-controller = "0.0.0.0:9090"`** 是有意的（多环境部署），安全靠 `SECRET` 强制认证。

## 模块关系

`constants.nix` 被 `tproxy.nix` 和 `mihomo.nix` 直接 `import`（不是 NixOS module options）。改端口/标记只需改 `constants.nix`，两边自动生效。

| 常量 | 值 | 用途 |
|------|-----|------|
| `tproxyPort` | 7894 | TPROXY 监听 |
| `dnsPort` | 1053 | Mihomo DNS |
| `routingMark` | 6666 | fwmark |
| `routingTable` | 100 | 策略路由表 |

## 订阅脚本安全模型

`mihomo.nix` 的 `subscribeScript` 流程：下载 → **黑名单净化** → baseConfig 覆盖 → SECRET 注入 → `mihomo -t` 验证 → 原子替换。

关键规则：
- 环境变量通过 systemd `EnvironmentFile=` 注入，**不要用 `source`**。
- `SECRET` 是必需项，缺失时脚本 `exit 1`。
- 黑名单删除的键（`routing-mark`, `tun`, `listeners`, 各种 port, `allow-lan`, `bind-address`, `external-controller`, `secret`）不可由订阅控制——如需新增黑名单项，加在净化步骤的 `del()` 链中。
- `fallbackConfig` 通过 `removeAttrs` 去掉了 `external-controller`，确保无 SECRET 时不暴露 API。

## TPROXY 要点

- **不要设置 `routing-mark`** 为 TPROXY 的 mark（6666），否则 mihomo 出站走 local 路由表导致黑洞。
- `rp_filter=0` 和 `src_valid_mark=1` 是 TPROXY 必需的 sysctl。
- 只需 `CAP_NET_ADMIN`（所有端口 >1024，无需 `CAP_NET_BIND_SERVICE`）。
- nftables `inet` 族的 DNS 劫持表天然覆盖 IPv4+IPv6。
- IPv6 转发被 sysctl 禁用 + `ip6 mihomo` 表 forward drop 双重阻断。

## Commit 规范

Conventional Commits，中文描述：`feat: 添加新功能` / `fix: 修复问题` / `refactor:` / `docs:` / `chore:`

## CI

GitHub Actions `release.yml`，仅 `workflow_dispatch` 手动触发，构建镜像并上传到 GitHub Release。

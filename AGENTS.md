# AGENTS.md

NixOS VM 透明代理网关（Mihomo + nftables TPROXY）。输出 qcow2 镜像。

## 项目定位

这是一个**只做单臂透明代理的 appliance**。设计目标是：插入现有网络、把客户端网关指过来就能用。

- 不是路由器，不做 NAT/DHCP/多接口
- 不是通用 NixOS 配置框架，不追求可扩展性
- 单用户 root 登录，不考虑多租户安全加固
- 配置尽量少，能跑就行，KISS 优先

## 命令

所有 flake 输出仅 `x86_64-linux`，macOS 上**什么都跑不了**。

```bash
just build    # 构建 VM 镜像 (qcow2)
just check    # nix flake check
just fmt      # nixfmt (RFC style)
just update   # 更新 flake inputs
```

无测试套件。验证手段是 `just check` 或 `just fmt`。

## 架构约束

- **单臂代理**：只拦截 transit（转发）流量，不代理本机 OUTPUT。**不要加 OUTPUT 链**。
- **Appliance 模式**：VM 内 `nix.enable = false`，无法在目标机上运行 Nix。
- **`firewall.enable = false`** 是有意的，nftables 规则由 `tproxy.nix` 直接管理。
- **`external-controller = "0.0.0.0:9090"`** 是有意的（多环境部署），安全靠 `SECRET` 强制认证。
- **不要加 hardening**：单用户 appliance，`ProtectSystem`/`PrivateTmp` 等是多余的。

## 模块关系

`constants.nix` 被 `tproxy.nix` 和 `mihomo.nix` 直接 `import`（不是 NixOS module options）。改端口/标记只需改 `constants.nix`，两边自动生效。

| 常量 | 值 | 用途 |
|------|-----|------|
| `tproxyPort` | 7894 | TPROXY 监听 |
| `dnsPort` | 1053 | Mihomo DNS |
| `routingMark` | 6666 | fwmark |
| `routingTable` | 100 | 策略路由表 |

## 订阅机制

环境变量文件：`/etc/mihomo/env`（`CONFIG_URL` + `SECRET`），用户首次部署时手动创建。

三个 systemd 单元协作：

| 单元 | 触发方式 | 职责 |
|------|----------|------|
| `mihomo-subscribe.path` | 监听 `/etc/mihomo/env` 变化 | 文件创建或修改时触发 subscribe |
| `mihomo-subscribe.timer` | `OnUnitActiveSec=6h` | 周期性更新 |
| `mihomo-subscribe.service` | 被 path/timer 触发 | 下载 → 黑名单净化 → baseConfig 覆盖 → SECRET 注入 → `mihomo -t` 验证 → 替换配置 → 重启 mihomo |

关键规则：
- 环境变量通过 systemd `EnvironmentFile=` 注入，**不要用 `source`**。
- `SECRET` 是必需项，缺失时脚本 `exit 1`；`CONFIG_URL` 缺失时 `exit 0`（首次部署尚未配置）。
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

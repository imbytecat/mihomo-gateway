# AGENTS.md

NixOS 透明代理网关（Mihomo + nftables TPROXY）。部署：qcow2 镜像 / nixos-anywhere；日常更新走 nixos-rebuild。

## 项目定位

**单臂透明代理 appliance**：插入现有网络、把客户端网关指过来即可。

- 不是路由器，不做 NAT/DHCP/多接口
- 不是通用 NixOS 配置框架，不追求可扩展性
- 单用户 root，KISS 优先

## 命令

所有 flake 输出仅 `x86_64-linux`。

```bash
just build       # 构建 qcow2 镜像 (vm profile)
just install H   # nixos-anywhere 装 bare-metal 配置到目标机
just switch H    # nixos-rebuild switch 更新已部署的 gateway
just check       # nix flake check（构建 vm + bare-metal toplevel）
just fmt         # nixfmt
just update      # 更新 flake inputs
```

无测试套件。

## 架构约束

### 模块分层

```
modules/  - 平台无关
  constants.nix / tproxy.nix / mihomo.nix / core.nix
profiles/ - 平台适配
  vm.nix          # qcow2 专用瘦身
  bare-metal.nix  # 物理机 / nixos-anywhere
  disko.nix       # 分区方案
```

`modules/core.nix` = `imports tproxy + mihomo` + 通用 networking/ssh/resolved/timezone，**不绑任何平台假设**（无 fileSystems / 无 boot loader / 无 nix.enable 决策）。`profiles/*` 才能写这些硬编码。

### 单臂代理 / Appliance 行为

- **只拦截 transit（forward）流量**，不代理本机 OUTPUT。**不要加 OUTPUT 链**。
- **`firewall.enable = false`** 是有意的，nftables 规则由 `modules/tproxy.nix` 直接管理。
- **`external-controller = "0.0.0.0:9090"`** 是有意的，安全靠 `SECRET` 强制认证。
- **不加 hardening**（`ProtectSystem`/`PrivateTmp` 等）：单用户 appliance 不需要。

### qcow2 vs bare-metal 的差异

| 项 | vm.nix | bare-metal.nix |
|----|--------|----------------|
| `profiles/minimal` | 加载 | 不加载 |
| `profiles/headless` | 加载 | 不加载 |
| `profiles/qemu-guest` | 加载 | 不加载 |
| `boot.growPartition` | `true` | 不设 |
| `boot.loader.efi.canTouchEfiVariables` | `false`（镜像构建无 efivarfs） | `true` |
| `boot.kernelParams` 串口 | 设 | 不设 |
| `fileSystems` | 硬编 by-label | 由 disko 生成 |
| `services.qemuGuest.enable` | `true` | 不设 |

**qcow2 体积敏感**，新增 vm profile 配置前先想下能不能砍。bare-metal 随意。

`nix.enable` 在 `modules/core.nix` 里两种 profile 共用：纯 flake 工作流（`channel.enable = false`、`nixPath = []`），qcow2 因此也支持就地 `nixos-rebuild switch --flake`。

## 模块关系

`modules/constants.nix` 被 `tproxy.nix` 和 `mihomo.nix` 直接 `import`（不是 NixOS module options）。改端口/标记只需改 `constants.nix`，两边自动生效。

| 常量 | 值 | 用途 |
|------|-----|------|
| `tproxyPort` | 7894 | TPROXY 监听 |
| `mixedPort` | 7890 | HTTP+SOCKS5 混合代理 |
| `dnsPort` | 1053 | Mihomo DNS |
| `routingMark` | 6666 | fwmark |
| `routingTable` | 100 | 策略路由表 |

## 订阅机制

环境变量文件：`/etc/mihomo/env`（`CONFIG_URL` + `SECRET`），首次部署时手动创建。

三个 systemd 单元协作：

| 单元 | 触发 | 职责 |
|------|------|------|
| `mihomo-subscribe.path` | 监听 `/etc/mihomo/env` 变化 | 文件创建/修改即触发 |
| `mihomo-subscribe.timer` | `OnUnitActiveSec=6h` | 周期性更新 |
| `mihomo-subscribe.service` | path/timer 触发 | 下载 → 黑名单净化 → `yq load()` 合并 baseConfig → SECRET 注入 → `mihomo -t` 验证 → 备份旧配置 → 替换 → 重启 mihomo |

Fallback 配置通过 `systemd.tmpfiles.rules` 的 `C`（copy-if-absent）部署到 `config.yaml`，不走 preStart / activationScripts。

关键规则：
- 环境变量通过 systemd `EnvironmentFile=` 注入，**不要用 `source`**。
- `SECRET` 必需（缺失 `exit 1`）；`CONFIG_URL` 缺失时 `exit 0`（首次部署尚未配置）。
- 黑名单删除的键（`routing-mark`, `tun`, `listeners`, 各种 port, `allow-lan`, `bind-address`, `external-controller`, `secret`）**不可由订阅覆盖**。新增黑名单项加到 subscribe 脚本的 `del()` 链。
- `fallbackConfig` 通过 `removeAttrs` 去掉 `external-controller`，保证无 SECRET 时不暴露 API。

## TPROXY 必守约束

详细排查手册和已踩坑案例见 `.opencode/skills/mihomo/SKILL.md`（触发词：`mihomo`/`tproxy`/`clash meta` 等）。下面只列**改代码前必看**的硬约束：

- **不要设 `routing-mark`**：nftables 只有 PREROUTING 无 OUTPUT，mihomo 出站不会被拦截；设了 ip rule 会把出站路由回本机形成黑洞。
- **使用 `tproxy-port` 而非 `listeners`**：效果相同，更简单。
- **rp_filter 必须通过 networkd 逐接口禁用**（`en* eth*` + `lo` 都要）。sysctl `all`/`default` 不足以覆盖 NixOS 默认值 2。
- **必须放开 `AF_NETLINK`**：上游 `services.mihomo` 默认只允许 `AF_INET{,6}`，会让所有 UDP DIRECT 静默失败（日志 `netlinkrib: address family not supported by protocol`）。
- **不引入 BBRv3**：未进主线内核；BBR+fq 就是当前最优组合。
- IPv6 转发被 sysctl + `ip6 mihomo` forward drop 双重阻断，不要在别处"放回"。
- `tproxy.nix` 的 sysctl 是最小完整集，不要再加调优项。

## 代码风格

- 注释只写**非显而易见的约束、陷阱或 WHY**（如 rp_filter、AF_NETLINK 为什么要改）。不要复述代码本身在做什么——代码就是注释。
- Nix 格式化用 `nixfmt`（`just fmt`），RFC style。

## 工具与资源

- **Skill**：`.opencode/skills/mihomo/SKILL.md`——Mihomo CLI/配置速查 + TPROXY 深度排查手册（rp_filter、AF_NETLINK、`skb:kfree_skb` tracepoint 流程等）。遇到代理问题先读这里，而不是凭记忆复现。
- **MCP**：`opencode.jsonc` 启用了 `mcp-nixos`，可查询 NixOS 选项/包以避免瞎猜属性名。

## Commit 规范

Conventional Commits，中文描述：`feat:` / `fix:` / `refactor:` / `docs:` / `chore:`。

## CI

`.github/workflows/release.yml`，仅 `workflow_dispatch` 手动触发：`just build` → 上传 qcow2 到 GitHub Release。

## 镜像

国内镜像只写在 `modules/core.nix` 的 `nix.settings.substituters`（SJTU 优先），即 gateway 自己 `nixos-rebuild switch` 时用。开发机 / CI / `just install|switch` 都走默认 cache.nixos.org——本机构建后 SCP 推送，目标机不 substitute（`--no-substitute-on-destination`）。

---
name: mihomo
description: "Mihomo (Clash Meta) 代理内核参考。用于 Mihomo 配置、TPROXY 设置、代理规则或订阅管理。触发词: mihomo, clash meta, tproxy, proxy rules, subscription config。"
---

# Mihomo 参考指南

## 官方资源

| 资源     | 地址                                              | 用途           |
| -------- | ------------------------------------------------- | -------------- |
| 文档     | https://wiki.metacubex.one/config/                | 配置参考       |
| 源码     | https://github.com/MetaCubeX/mihomo/tree/Meta     | 实现细节       |
| Alpha 分支 | https://github.com/MetaCubeX/mihomo/tree/Alpha   | 最新特性       |

**注意**: 只使用 Meta 或 Alpha 分支，其他分支可能有问题。

## CLI 用法

```bash
mihomo -h              # 帮助
mihomo -t -f <config>  # 验证配置 (0=成功, 1=失败)
mihomo -d <dir>        # 设置配置目录
mihomo -f <file>       # 指定配置文件
```

## TPROXY 必需字段

```yaml
tproxy-port: 7894      # TPROXY 监听端口
routing-mark: 6666     # 绕过标记 (须与 nftables 匹配)
```

## 常用模式

### 先验证后应用

```bash
curl -fsSL "$URL" -o /tmp/config.yaml
mihomo -t -f /tmp/config.yaml && mv /tmp/config.yaml /etc/mihomo/config.yaml
```

### 强制注入 TPROXY 字段

```bash
yq -i '.tproxy-port = 7894 | .routing-mark = 6666' config.yaml
```

## 查阅方法论

**关键**: 文档和源码需要交叉验证，两者都不完整。

1. **先查文档** - wiki.metacubex.one/config/ 获取配置选项和示例
2. **再查源码** - 验证实际默认值和行为
   - `config/config.go` - 配置结构定义
   - `main.go` - CLI 参数
   - `hub/executor/` - 运行时行为
3. **交叉验证** - 源码显示实际默认值，文档显示推荐用法

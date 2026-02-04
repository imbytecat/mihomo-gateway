---
name: mihomo
description: |
  Mihomo (Clash Meta) proxy kernel reference. Use when working with Mihomo configuration, TPROXY setup, proxy rules, or subscription management.
  Triggers: mihomo, clash meta, tproxy, proxy rules, subscription config, mihomo validation, mihomo CLI.
---

# Mihomo

## Overview

Mihomo is a rule-based network tunnel (fork of Clash). This skill provides official resource references and common patterns for configuration and CLI usage.

## Official Resources

| Resource | URL | Use Case |
|----------|-----|----------|
| Documentation | https://wiki.metacubex.one/config/ | Configuration reference |
| Source Code | https://github.com/MetaCubeX/mihomo/tree/Meta | Implementation details, CLI flags |
| Alpha Branch | https://github.com/MetaCubeX/mihomo/tree/Alpha | Latest features |

IMPORTANT: Only use Meta or Alpha branches. Other branches may have issues.

## CLI Reference

```bash
mihomo -h              # Help
mihomo -t -f <config>  # Validate config (exit 0=success, 1=fail)
mihomo -d <dir>        # Set config directory
mihomo -f <file>       # Specify config file
```

## TPROXY Required Fields

When using TPROXY mode, config MUST include:

```yaml
tproxy-port: 7894      # TPROXY listening port
routing-mark: 6666     # Mark for bypass (must match nftables)
```

## Common Patterns

### Validate Before Apply

```bash
curl -fsSL "$URL" -o /tmp/config.yaml
mihomo -t -f /tmp/config.yaml && mv /tmp/config.yaml /etc/mihomo/config.yaml
```

### Force Inject TPROXY Fields

```bash
yq -i '.tproxy-port = 7894 | .routing-mark = 6666' config.yaml
```

## Lookup Strategy

CRITICAL: Always cross-validate between source code AND documentation. Neither is complete alone.

### Step 1: Check Documentation First
- wiki.metacubex.one/config/ for configuration options and examples
- Documentation shows recommended values (e.g., routing-mark: 6666)

### Step 2: Verify in Source Code
Use webfetch to get raw files from correct branches:
```
https://raw.githubusercontent.com/MetaCubeX/mihomo/Meta/<path>
https://raw.githubusercontent.com/MetaCubeX/mihomo/Alpha/<path>
```

Key source files:
- config/config.go - Config struct definitions, default values
- main.go - CLI flags
- hub/executor/ - Runtime behavior

### Step 3: Cross-Validate
- Source shows actual defaults (e.g., routing-mark defaults to 0 in code)
- Documentation shows recommended usage (e.g., routing-mark: 6666 in examples)
- Both are needed for complete understanding

## Search Tools

DO NOT use grep_app for mihomo - it may not filter by branch correctly.

CORRECT approach:
```
webfetch https://raw.githubusercontent.com/MetaCubeX/mihomo/Meta/config/config.go
webfetch https://wiki.metacubex.one/config/general/
```

WRONG approach:
```
grep_app_searchGitHub repo:MetaCubeX/mihomo  # May search wrong branches
```

## Default Values Reference

| Field | Source Default | Doc Example |
|-------|----------------|-------------|
| tproxy-port | 0 (disabled) | 7894 |
| routing-mark | 0 (disabled) | 6666 |
| mixed-port | 0 (disabled) | 7890 |
| allow-lan | false | true |
| find-process-mode | strict | off (for routers)

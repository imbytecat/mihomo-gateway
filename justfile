system := "x86_64-linux"

# 列出所有可用命令
default:
    @just --list --unsorted

# 构建 qcow2 虚拟机镜像
build:
    nix build '.#packages.{{system}}.image'

# 检查 flake
check:
    nix flake check --no-build

# 格式化 nix 文件
fmt:
    nix fmt

# 查看 flake 输出
show:
    nix flake show

# 更新 flake inputs
update:
    nix flake update

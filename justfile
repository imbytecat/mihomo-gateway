system := "x86_64-linux"

# 列出所有可用命令
default:
    @just --list --unsorted

# 构建 qcow2 虚拟机镜像
build:
    nix build '.#image'

# 用 nixos-anywhere 远程装系统到目标机（裸机 / 已有 Linux，会格式化磁盘）
# kexec 镜像和 closure 全在本机构建后 SCP 推送，目标机不需要访问 github / cache.nixos.org
install HOST:
    nix run github:nix-community/nixos-anywhere -- \
      --kexec "$(nix build --no-link --print-out-paths github:nix-community/nixos-images#packages.x86_64-linux.kexec-installer-nixos-unstable-noninteractive)/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz" \
      --no-substitute-on-destination \
      --flake '.#bare-metal' root@{{HOST}}

# 向已装好 NixOS 的目标机推送 bare-metal 配置
switch HOST:
    nixos-rebuild switch --flake '.#bare-metal' --target-host root@{{HOST}}

# 检查 flake（等价于构建 vm + bare-metal toplevel，仅 Linux amd64）
check:
    nix flake check

# 格式化 nix 文件
fmt:
    nix fmt

# 查看 flake 输出
show:
    nix flake show

# 更新 flake inputs
update:
    nix flake update

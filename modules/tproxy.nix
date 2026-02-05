# TPROXY 网络层 (sysctl + routing + nftables)
{ config, lib, ... }:

let
  constants = import ./constants.nix;
  inherit (constants)
    tproxyPort
    routingMark
    routingTable
    ;
in
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;

    # TPROXY 必需
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
    "net.ipv4.conf.all.src_valid_mark" = 1;
    "net.ipv4.conf.default.src_valid_mark" = 1;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # 阻断 IPv6 转发，防止绕过代理
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv6.conf.default.forwarding" = 0;
  };

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip mihomo {
        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;

          meta mark ${toString routingMark} return
          ip daddr { 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } return
          fib daddr type { local, broadcast, multicast } return
          meta l4proto { tcp, udp } tproxy to :${toString tproxyPort} meta mark set ${toString routingMark}
        }
      }

      table ip6 mihomo {
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
      }
    '';
  };

  networking.iproute2.enable = true;

  systemd.network = {
    enable = true;
    networks."99-tproxy" = {
      matchConfig.Name = "lo";
      routingPolicyRules = [
        {
          FirewallMark = routingMark;
          Table = routingTable;
          Priority = 100;
        }
      ];
      routes = [
        {
          Destination = "0.0.0.0/0";
          Type = "local";
          Table = routingTable;
        }
      ];
    };
  };
}

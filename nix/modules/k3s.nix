{ config, lib, pkgs, ... }:

let
  cfg = config.k3s;
in
{
  options.k3s = {
    role = lib.mkOption {
      type = lib.types.enum [ "server" "agent" ];
      description = "server or agent";
    };

    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "nix-k3s-01.backend.9rv.org";
      description = "address of server";
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = [
      6443  # k3s API
      10250 # kubelet metrics
    ];

    networking.firewall.allowedUDPPorts = [ 8472 ];

    services.k3s = {
      enable = true;
      role = cfg.role;
      tokenFile = "/etc/secrets/k3s_token";
      serverAddr = lib.mkIf (cfg.role == "agent") "https://${cfg.serverAddr}:6443";

      extraFlags = builtins.concatStringsSep " " [
        "--disable=traefik"
        "--disable=servicelb"
      ];
    };
  };
}

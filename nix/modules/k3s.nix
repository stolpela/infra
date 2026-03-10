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

    systemd.services.k3s = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
    };

    services.k3s = {
      enable = true;
      role = cfg.role;
      tokenFile = config.sops.secrets.k3s_token.path;

      extraFlags = builtins.concatStringsSep " " (
        [
          "--disable=traefik"
          "--disable=servicelb"
        ]
        ++ lib.optionals (cfg.role == "agent") [
          "--server=https://${cfg.serverAddr}:6443"
        ]
      );
    };
  };
}

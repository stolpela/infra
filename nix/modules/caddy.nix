{ config, lib, pkgs, ... }:

let
  cfg = config.caddy;
in
{
  options.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy";

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.reverseProxy = lib.mkOption {
          type = lib.types.str;
          description = "Backend address to reverse proxy to (e.g. localhost:3000)";
        };
      });
      default = {};
      description = "Virtual hosts to configure as reverse proxies";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;

      virtualHosts = lib.mapAttrs (domain: hostCfg: {
        extraConfig = "reverse_proxy ${hostCfg.reverseProxy}";
      }) (lib.mapAttrs' (domain: hostCfg:
        lib.nameValuePair "http://${domain}" hostCfg
      ) cfg.virtualHosts);
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}

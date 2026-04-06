{ config, lib, pkgs, ... }:

let
  cfg = config.caddy;

  caddyCloudflare = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
    hash = lib.fakeHash;
  };
in
{
  options.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy";

    cloudflareApiTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secrets/cloudflare_api_token";
      description = "secret location";
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.reverseProxy = lib.mkOption {
          type = lib.types.str;
          description = "Backend address";
        };
      });
      default = {};
      description = "hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = caddyCloudflare;

      globalConfig = ''
        acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      '';

      virtualHosts = lib.mapAttrs (domain: hostCfg: {
        extraConfig = "reverse_proxy ${hostCfg.reverseProxy}";
      }) cfg.virtualHosts;
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = cfg.cloudflareApiTokenFile;

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}

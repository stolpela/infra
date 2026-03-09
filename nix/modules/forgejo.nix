{ config, lib, pkgs, ... }:

let
  cfg = config.forgejo;
in
{
  options.forgejo = {
    enable = lib.mkEnableOption "Forgejo git hosting service";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain name for the Forgejo instance";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTP port for the Forgejo web interface";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "SSH port for Git over SSH";
    };
  };

  config = lib.mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      stateDir = "/var/lib/forgejo";

      settings = {
        DEFAULT = {
          APP_NAME = "Forgejo";
        };

        server = {
          DOMAIN = cfg.domain;
          ROOT_URL = "https://${cfg.domain}/";
          HTTP_PORT = cfg.httpPort;
          SSH_PORT = cfg.sshPort;
          START_SSH_SERVER = true;
        };

        service = {
          DISABLE_REGISTRATION = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      cfg.sshPort
    ];
  };
}

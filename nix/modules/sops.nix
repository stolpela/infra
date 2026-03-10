{ config, lib, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      k3s_token = {};
      cloudflare_api_token_9rv = {
        owner = "caddy";
      };
      cloudflare_api_token_larsolo = {
        owner = "caddy";
      };
    };
  };
}

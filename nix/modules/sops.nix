{ config, lib, pkgs, ... }:

{
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      k3s_token.file = ../../secrets/k3s_token.age;
      cloudflare_api_token_9rv = {
        file = ../../secrets/cloudflare_api_token_9rv.age;
        owner = "caddy";
      };
      cloudflare_api_token_larsolo = {
        file = ../../secrets/cloudflare_api_token_larsolo.age;
        owner = "caddy";
      };
    };
  };
}

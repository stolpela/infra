# nix-k3s-01
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking.hostName = "nix-k3s-01";

  cluster01.vlans = {
    enable = true;
    interfaces = {
      backend = "ens18";
      vpn1     = "ens19";
      vpn2    = "ens20";
    };
  };

  k3s = {
    role = "server";
  };

  forgejo = {
    enable = true;
    domain = "git.9rv.org";
  };

  nfs = {
    enable = true;
    mounts."/mnt/s1/media" = {
      device = "nas.9rv.org:/mnt/s1/data/media";
      options = [ "nfsvers=4" "soft" "timeo=15" ];
    };
  };

  caddy = {
    enable = true;
    virtualHosts = {
      "git.9rv.org" = {
        reverseProxy = "localhost:3000";
      };
    };
  };

}

# nix-k3s-02-gpu
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nix-k3s-02-gpu";

  networking.interfaces.ens18.useDHCP = true;

  k3s = {
    role = "agent";
    serverAddr = "nix-k3s-01.backend.9rv.org";
  };
}

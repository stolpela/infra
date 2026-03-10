# nix-k3s-02-gpu
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Intel Arc A380 GPU support
  boot.kernelParams = [ "i915.force_probe=56a5" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.kernelModules = [ "xe" "i915" ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
      level-zero
      vpl-gpu-rt
    ];
  };

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
  ];

  networking.hostName = "nix-k3s-02-gpu";

  networking.interfaces.ens18.useDHCP = true;

  k3s = {
    role = "agent";
    serverAddr = "nix-k3s-01.backend.9rv.org";
  };
}

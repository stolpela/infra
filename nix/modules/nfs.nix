{ config, lib, pkgs, ... }:

let
  cfg = config.nfs;
in
{
  options.nfs = {
    enable = lib.mkEnableOption "NFS client mounts";

    mounts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "NFS remote path (e.g. nas:/share)";
          };
          options = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "nfsvers=4" "soft" "timeo=15" ];
            description = "Mount options";
          };
        };
      });
      default = {};
      description = "NFS mounts keyed by local mount point";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.nfs-utils ];

    fileSystems = lib.mapAttrs (mountPoint: mountCfg: {
      device = mountCfg.device;
      fsType = "nfs";
      options = mountCfg.options;
    }) cfg.mounts;
  };
}

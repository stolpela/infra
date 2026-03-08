# VLAN networking
{ config, pkgs, lib, ... }:

{
  options.cluster01.vlans = {
    enable = lib.mkEnableOption "VLAN networking";

    interfaces = {
      backend = lib.mkOption {
        type = lib.types.str;
        default = "ens18";
        description = "Interface on VLAN 2";
      };
      vpn1 = lib.mkOption {
        type = lib.types.str;
        default = "ens19";
        description = "Interface on VLAN 3";
      };
      vpn2 = lib.mkOption {
        type = lib.types.str;
        default = "ens20";
        description = "Interface on VLAN 4";
      };
    };
  };

  config = lib.mkIf config.cluster01.vlans.enable {
    networking = {
      interfaces = {
        "${config.cluster01.vlans.interfaces.backend}" = {
          useDHCP = true;
        };

        "${config.cluster01.vlans.interfaces.vpn1}" = {
          useDHCP = true;
        };

        "${config.cluster01.vlans.interfaces.vpn2}" = {
          useDHCP = true;
        };
      };


      dhcpcd.extraConfig = ''
        interface ${config.cluster01.vlans.interfaces.vpn1}
        nogateway

        interface ${config.cluster01.vlans.interfaces.vpn2}
        nogateway
      '';
    };
  };
}

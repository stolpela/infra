{
  description = "=nix-k3s-cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    nixosConfigurations = {

      nix-k3s-01 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./nix/hosts/nix-k3s-01/configuration.nix
          ./nix/modules/common.nix
          ./nix/modules/k3s.nix
          ./nix/modules/vlans.nix
          ./nix/modules/forgejo.nix
          ./nix/modules/nfs.nix
          ./nix/modules/caddy.nix
        ];
      };

      nix-k3s-02-gpu = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./nix/hosts/nix-k3s-02-gpu/configuration.nix
          ./nix/modules/common.nix
          ./nix/modules/k3s.nix
        ];
      };

    };
  };
}

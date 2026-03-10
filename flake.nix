{
  description = "=nix-k3s-cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    nixosConfigurations = {

      nix-k3s-01 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          agenix.nixosModules.default
          ./nix/hosts/nix-k3s-01/configuration.nix
          ./nix/modules/common.nix
          ./nix/modules/sops.nix
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
          agenix.nixosModules.default
          ./nix/hosts/nix-k3s-02-gpu/configuration.nix
          ./nix/modules/common.nix
          ./nix/modules/sops.nix
          ./nix/modules/k3s.nix
        ];
      };

    };
  };
}

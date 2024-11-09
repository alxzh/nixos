{
  description = "Vizor Server flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable }:
  let
        system = "x86_64-linux";
        overlay-unstable = final: prev: {
                unstable = import nixpkgs-unstable {
                        inherit system;
                        config.allowUnfree = true;
                };
        };
  in {
        nixosConfigurations.vizor = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                        # Overlays-module makes "pkgs.unstable" available in configuration.nix
                        ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
                        ./configuration.nix
                ];
        };
  };
}

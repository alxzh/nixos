{
  description = "Vizor Server flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    caddy-patched = {
    	url = "github:strideynet/nixos-caddy-patched/main";
    	inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable,  ... }@inputs:
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
		specialArgs = { inherit inputs; };
                modules = [
                        # Overlays-module makes "pkgs.unstable" available in configuration.nix
                        ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
                        ./configuration.nix
                ];
        };
  };
}

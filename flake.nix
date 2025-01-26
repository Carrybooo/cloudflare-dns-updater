{
  description = "A Cloudflare DNS updater written in Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      # Import the nixos module once, globally.
      globalNixosModule = import ./module.nix;
      perSystem = flake-utils.lib.eachDefaultSystem (system: let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
  
        updaterPackage = import ./default.nix { inherit pkgs lib; };
      in {
        packages = {
          default = updaterPackage;
          cloudflare-dns-updater = updaterPackage;
        };

        apps = {
          default = {
            type = "app";
            program = "${updaterPackage}/bin/cloudflare-dns-updater";
          };
        };

        devShells = {
          default = import ./devShell.nix { inherit pkgs lib; };
        };
      });
    in
    perSystem // {
      nixosModules = {
        cloudflare-dns-updater = globalNixosModule;
      };
    };
}

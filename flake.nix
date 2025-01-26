{
  description = "A Cloudflare DNS auto-updater written in Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # Read Cargo metadata
        manifest = lib.importTOML ./Cargo.toml;
        pname = manifest.package.name;
        version = manifest.package.version;

      in {
        packages.cloudflare-dns-updater = pkgs.rustPlatform.buildRustPackage {
          inherit pname version;
          src = pkgs.lib.cleanSource ./.;
          cargoLock.lockFile = ./Cargo.lock;

          nativeBuildInputs = with pkgs; [
            pkg-config
            openssl
          ];

          preBuild = ''
            export PKG_CONFIG_PATH=${pkgs.openssl.dev}/lib/pkgconfig
          '';

          meta = with lib; {
            description = "A Cloudflare DNS updater written in Rust";
            homepage = "https://github.com/Carrybooo/cloudflare-dns-updater";
            license = licenses.mit;
          };
        };

        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            rust-analyzer
            rustfmt
            pkg-config
            openssl
          ];
          shellHook = ''
            export PKG_CONFIG_PATH=${pkgs.openssl.dev}/lib/pkgconfig
            export PKG_CONFIG_ALLOW_CROSS=1
            export RUST_BACKTRACE=1
          '';
        };

        defaultPackage = self.packages.${system}.cloudflare-dns-updater;
        defaultApp = self.packages.${system}.cloudflare-dns-updater;
      }
    );
}

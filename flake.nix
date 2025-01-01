{
  description = "A flake for the DNS updater project";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    lib = pkgs.lib;
  in {
    packages.x86_64-linux.cloudflare-dns-updater = pkgs.rustPlatform.buildRustPackage rec {
      pname = "cloudflare-dns-updater";
      version = "0.2.0";

      src = pkgs.fetchFromGitHub {
        owner = "Carrybooo";
        repo = "cloudflare-dns-updater";
        rev = "v${version}";
        hash = "sha256-3P7o70WEyQl2DyiKgKdMOuRgCa9y5Ryp8hVo1AY0seo=";
      };

      nativeBuildInputs = [ pkgs.pkg-config ];
      buildInputs = [ pkgs.openssl ];

      configurePhase = ''
        export PKG_CONFIG_PATH=${pkgs.openssl.dev}/lib/pkgconfig
      '';

      cargoHash = "sha256-kw24pr0xzyOmAfh/2nHwWy7oCycdWUPf0MAsPeTxNx0=";

      meta = with lib; {
        description = "A DNS updater written in Rust";
        homepage = "https://github.com/Carrybooo/cloudflare-dns-updater";
        license = licenses.mit;
      };
    };

    nixosModules.cloudflare-dns-updater = {
      options = {
        cloudflare-dns-updater = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the Cloudflare DNS updater service.";
          };

          config = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "The configuration for Cloudflare DNS Updater.";
          };

          configPath = lib.mkOption {
            type = lib.types.str;
            default = "/etc/cloudflare-dns-updater/config.toml";
            description = "Path to the configuration file for Cloudflare DNS Updater.";
          };
        };
      };

      config = { config, pkgs, lib, ... }: let
        updaterPackage = self.packages.x86_64-linux.cloudflare-dns-updater;
      in {
        environment.etc."cloudflare-dns-updater/config.toml".text = config.cloudflare-dns-updater.config;

        systemd.services.cloudflare-dns-updater = {
          description = "Cloudflare DNS Updater Service";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${updaterPackage}/bin/cloudflare-dns-updater --configpath ${config.cloudflare-dns-updater.configPath}";
            Restart = "on-failure";
          };
          enabled = config.cloudflare-dns-updater.enable;
        };
      };
    };
  };
}

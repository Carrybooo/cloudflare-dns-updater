{
  description = "A flake for the DNS updater project";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.cloudflare-dns-updater = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
    in pkgs.rustPlatform.buildRustPackage rec {
      pname = "cloudflare-dns-updater";
      version = "0.1.0";

      # Replace with your GitHub repo details
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

      cargoHash = "sha256-lW4pqPm79u4baoahVGjTw9dyc6bG3bSAj9hf0NZj+DY=";

      meta = with pkgs.lib; {
        description = "A DNS updater written in Rust";
        homepage = "https://github.com/Carrybooo/cloudflare-dns-updater";
        license = licenses.mit;
      };
    };
  };

  nixosModules.cloudflare-dns-updater = {
    options.cloudflare-dns-updater = {
      config = pkgs.lib.mkOption {
        type = pkgs.lib.types.str;
        default = "";
        description = "The configuration for Cloudflare DNS Updater";
      };
      configPath = pkgs.lib.mkOption {
        type = pkgs.lib.types.str;
        default = "/etc/cloudflare-dns-updater/config.toml";
        description = "Path to the configuration file for Cloudflare DNS Updater.";
      };
      enable = pkgs.lib.mkOption {
        type = pkgs.lib.types.bool;
        default = false;
        description = "Enable the Cloudflare DNS updater service.";
      };
    };


    config = { config, pkgs, ... }: {
      environment.etc."cloudflare-dns-updater/config.toml".text = config.cloudflare-dns-updater.config;

      systemd.services.cloudflare-dns-updater = {
        description = "Cloudflare DNS Updater Service";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.cloudflare-dns-updater}/bin/cloudflare-dns-updater --configpath ${config.cloudflare-dns-updater.configPath}";
          Restart = "on-failure";
        };
        enabled = config.cloudflare-dns-updater.enable;
      };
    };
  };
}

{ config, lib, pkgs, ... }:

with lib;

{
  options.services.cloudflare-dns-updater = {
    enable = mkEnableOption "Enable the Cloudflare DNS updater service";
    package = mkOption {
      type = types.package;
      default = pkgs.cloudflare-dns-updater;
      description = "The package (binary) to run.";
    };
    configPath = mkOption {
      type = types.str;
      default = "/etc/cloudflare-dns-updater/config.toml";
      description = "Path to the Cloudflare DNS updater configuration file.";
    };
  };

  config = mkIf config.services.cloudflare-dns-updater.enable {
    systemd.services.cloudflare-dns-updater = {
      description = "Cloudflare DNS updater service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${config.services.cloudflare-dns-updater.package}/bin/cloudflare-dns-updater --configpath ${config.services.cloudflare-dns-updater.configPath}";
        Restart = "always";
      };
    };
  };
}

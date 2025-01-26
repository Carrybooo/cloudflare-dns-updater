{ pkgs, lib }:
let
  manifest = lib.importTOML ./Cargo.toml;
in
  pkgs.rustPlatform.buildRustPackage {
    pname = manifest.package.name;
    version = manifest.package.version;

    src = pkgs.lib.cleanSource ./.;

    cargoLock = {
      lockFile = ./Cargo.lock;
    };

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
      maintainers = [ "YourName" ];
    };
}


{ pkgs ? import <nixpkgs> { } }:
let
  repo = pkgs.fetchFromGitHub {
    owner = "Carrybooo";
    repo = "cloudflare-dns-updater";
    rev = "v0.2.0";
    hash = "sha256-xkkboaq+SmM4Cx6NXU11ipawoqySD3atUhAPWNPc+oU=";
  };
  manifest = pkgs.lib.importTOML "${repo}/Cargo.toml";
in
pkgs.rustPlatform.buildRustPackage rec {
  pname = manifest.package.name;
  version = manifest.package.version;

  src = repo;

  cargoHash = "sha256-/X2mGbJge5khMiXu8SYFQarDSBCRbWX7GwkuAv2q0ow=";

  nativeBuildInputs = with pkgs; [
    pkg-config
    openssl
  ];

  preBuild = ''
    export PKG_CONFIG_PATH=${pkgs.openssl.dev}/lib/pkgconfig
  '';

  meta = with pkgs.lib; {
    description = "A DNS updater written in Rust";
    homepage = "https://github.com/Carrybooo/cloudflare-dns-updater";
    license = licenses.mit;
  };
}

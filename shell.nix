{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.pkg-config
    pkgs.openssl
  ];
  shellHook = ''
    export PKG_CONFIG_PATH=${pkgs.openssl.out}/lib/pkgconfig
  '';
}

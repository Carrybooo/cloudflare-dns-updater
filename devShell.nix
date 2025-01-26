{ pkgs, lib }:

pkgs.mkShell {
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
}

{
  writeShellScriptBin,
  lib,
  mkNixpakPackage,
  nixpakModules,
  ungoogled-chromium,
  ...
}: let
  nixpakPackage = mkNixpakPackage {
    config = {...}: {
      app.package = ungoogled-chromium;
      imports = with nixpakModules; [
        gui-base
        network
        private-tmp
        ./nixpak-module.nix
      ];
    };
  };
in
  writeShellScriptBin "chromium" ''
    if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
      export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
    fi

    ${nixpakPackage |> lib.getExe} "$@"
  ''

{
  mkNixpakPackage,
  nixpakModules,
  mcp-server-browser,
  lib,
  writeShellScriptBin,
  sandbox,
  ...
}: let
  nixpakPackage = mkNixpakPackage {
    config = {...}: {
      app.package = mcp-server-browser;
      imports = with nixpakModules; [
        ../ungoogled-chromium/nixpak-module.nix
        gui-base
        network
        private-tmp
      ];
    };
  };
in
  writeShellScriptBin "mcp-server-browser" ''
    ${nixpakPackage |> lib.getExe} --executable-path ${sandbox.ungoogled-chromium |> lib.getExe} "$@"
  ''

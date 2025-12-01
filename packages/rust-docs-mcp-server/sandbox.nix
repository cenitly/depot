{
  lib,
  mkNixpakPackage,
  nixpakModules,
  rust-docs-mcp-server,
  sops,
  writeShellScriptBin,
  ...
}: let
  sandbox = mkNixpakPackage {
    config = {...}: {
      flatpak.appId = "ai.govcraft.RustDocsMcpServer";
      app.package = rust-docs-mcp-server;
      imports = with nixpakModules; [
        (import ./nixpak-module.nix)
        network
        private-tmp
      ];
    };
  };
in
  writeShellScriptBin "rustdocs_mcp_server" ''
    if [ -z "$OPENAI_API_KEY" ]; then
      export OPENAI_API_KEY="$(${sops |> lib.getExe} -d --extract '["keys"]["openai_api_key"]' ${../../secrets/keys.yaml})"
    fi

    ${sandbox |> lib.getExe} "$@"
  ''

{
  claude-code,
  lib,
  mkNixpakPackage,
  nixpakModules,
  writeShellScriptBin,
  writeTextFile,
  sandbox,
  coreutils,
  direnv,
  nix,
  findutils,
  bash,
  gawk,
  ...
}: let
  mcpServers = import ./mcp-servers.nix {inherit lib sandbox;};
  mcpJson = writeTextFile {
    name = "mcp.json";
    text =
      {inherit mcpServers;}
      |> builtins.toJSON;
  };
  nixpakPackage = mkNixpakPackage {
    config = {sloth, ...}: {
      app.package = claude-code;
      imports = with nixpakModules; [
        ../ungoogled-chromium/nixpak-module.nix
        gui-base
        network
        private-tmp
      ];
      flatpak.appId = "ai.claude.ClaudeCode";
      bubblewrap = {
        clearEnv = false;
        env = {
          "TERM" = sloth.env "TERM";
          "HOME" = sloth.homeDir;
          "USER" = sloth.env "USER";
          "PATH" = sloth.concat [(sloth.env "PATH") ":" (lib.makeBinPath [coreutils direnv nix findutils bash gawk])];
          # This variable is required to prevent SSL errors in Node.
          "SSL_CERT_FILE" = "/etc/ssl/certs/ca-bundle.crt";
          "SHELL" = sloth.env "SHELL";
        };
        # Much of this is for Direnv compatability.
        bind.rw = [
          (sloth.env "NIXPAK_WORKING_DIRECTORY")
          (sloth.concat' sloth.homeDir "/.claude")
          (sloth.concat' sloth.homeDir "/.claude.json")
          (sloth.concat' sloth.homeDir "/.claude.json.backup")
          (sloth.concat' sloth.xdgCacheHome "/claude-cli-nodejs")
          (sloth.concat' sloth.xdgDataHome "/nix")
          (sloth.concat' sloth.xdgCacheHome "/nix")
          (sloth.concat' sloth.xdgStateHome "/nix")
          (sloth.concat' sloth.xdgDataHome "/direnv")
        ];
        bind.ro = [
          (sloth.concat' sloth.xdgConfigHome "/nix")
          (sloth.concat' sloth.homeDir "/.ssh")
          (sloth.concat' sloth.homeDir "/.gitconfig")
          (sloth.concat' sloth.homeDir "/.bashrc")
          (sloth.concat' sloth.homeDir "/.bash_profile")
          "/bin/sh"
          "/etc/direnv"
          "/etc/nix"
          "/etc/static"
          "/nix/var/nix"
          "/run/current-system"
          "/usr/bin/env"
        ];
        # Required for raw terminal mode access.
        sharePgid = true;
      };
    };
  };
in
  writeShellScriptBin "claude" ''
    export NIXPAK_WORKING_DIRECTORY="$(pwd)"

    if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
      export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
    fi

    mkdir -p "$HOME/.claude"

    ${nixpakPackage |> lib.getExe} --mcp-config ${mcpJson} "$@"
  ''

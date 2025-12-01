{
  claude-code,
  lib,
  mkNixpakPackage,
  nixpakModules,
  sops,
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
  mcpServers = {
    rust-docs-mcp-server-hayro = {
      type = "stdio";
      command = sandbox.rust-docs-mcp-server |> lib.getExe;
      args = [
        "hayro@0.4.0"
      ];
      env = {};
    };
    rust-docs-mcp-server-hayro-svg = {
      type = "stdio";
      command = sandbox.rust-docs-mcp-server |> lib.getExe;
      args = [
        "hayro-svg@0.2.0"
      ];
      env = {};
    };
    docs-rs-mcp = {
      type = "stdio";
      command = sandbox.docs-rs-mcp |> lib.getExe;
      args = [
      ];
      env = {};
    };
    mcp-server-browser = {
      type = "stdio";
      command = sandbox.mcp-server-browser |> lib.getExe;
      args = [
      ];
      env = {};
    };
  };
  nixpakPackage = mkNixpakPackage {
    config = {sloth, ...}: let
      workingDir = sloth.env "NIXPAK_WORKING_DIRECTORY";
    in {
      app.package = claude-code;
      imports = with nixpakModules; [
        ../rust-docs-mcp-server/nixpak-module.nix
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
          [
            ((writeTextFile {
                name = ".mcp.json";
                text =
                  {
                    inherit mcpServers;
                  }
                  |> builtins.toJSON;
              })
              |> toString)
            (sloth.concat' workingDir "/.mcp.json")
          ]
        ];
        # Required for raw terminal mode access.
        sharePgid = true;
      };
    };
  };
in
  writeShellScriptBin "claude-code" ''
    export NIXPAK_WORKING_DIRECTORY="$(pwd)"

    if [ -z "$OPENAI_API_KEY" ]; then
      export OPENAI_API_KEY="$(${sops |> lib.getExe} -d --extract '["keys"]["openai_api_key"]' ${../../secrets/keys.yaml})"
    fi

    if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
      export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
    fi

    ${nixpakPackage |> lib.getExe} "$@"
  ''
# ls


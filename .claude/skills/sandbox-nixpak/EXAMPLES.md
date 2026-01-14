# Sandbox Examples

Comprehensive examples from this repository and common patterns.

## Minimal Examples

### MCP Server (Network Only)

The simplest sandbox for a CLI tool that only needs network access.

```nix
# packages/svelte-mcp/sandbox.nix
{
  mkNixpakPackage,
  nixpakModules,
  svelte-mcp,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = svelte-mcp;
    imports = with nixpakModules; [
      network
    ];
  };
}
```

### docs-rs-mcp

```nix
# packages/docs-rs-mcp/sandbox.nix
{
  mkNixpakPackage,
  nixpakModules,
  docs-rs-mcp,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = docs-rs-mcp;
    imports = with nixpakModules; [
      network
    ];
  };
}
```

---

## GUI Applications

### Figma Linux

Desktop application with file access.

```nix
# packages/figma-linux/sandbox.nix
{
  mkNixpakPackage,
  nixpakModules,
  figma-linux,
  lib,
  flatpak-xdg-utils,
  ...
}:
mkNixpakPackage {
  config = {sloth, ...}: {
    app.package = figma-linux;

    imports = with nixpakModules; [
      gui-base
      network
      private-tmp
    ];

    flatpak.appId = "com.figma.Figma";

    bubblewrap = {
      clearEnv = false;
      env = {
        "PATH" = sloth.concat [
          (sloth.env "PATH")
          ":"
          (lib.makeBinPath [flatpak-xdg-utils])
        ];
      };
      bind.rw = [
        (sloth.concat' sloth.xdgPicturesDir "/figma")
        (sloth.concat' sloth.xdgPicturesDir "/Figma")
        (sloth.concat' sloth.xdgConfigHome "/figma-linux")
      ];
    };
  };
}
```

---

## Browser

### Ungoogled Chromium

Browser with profile persistence and downloads.

```nix
# packages/ungoogled-chromium/nixpak-module.nix
{sloth, ...}: {
  bubblewrap.bind.rw = [
    # Profile storage
    [
      (sloth.mkdir (sloth.concat [sloth.appDataDir "/profile"]))
      (sloth.concat [sloth.xdgConfigHome "/chromium"])
    ]
    # Downloads
    (sloth.envOr "XDG_DOWNLOAD_DIR" (sloth.concat' sloth.homeDir "/Downloads"))
    # PKI certificates
    (sloth.concat' sloth.homeDir "/.pki")
  ];
}
```

```nix
# packages/ungoogled-chromium/sandbox.nix
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
        ./nixpak-module.nix  # Browser-specific config
      ];
    };
  };
in
  writeShellScriptBin "chromium" ''
    # Support dynamic CA certificates
    if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
      export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
    fi

    ${nixpakPackage |> lib.getExe} "$@"
  ''
```

---

## Complex Applications

### Claude Code

Full-featured terminal application with MCP server integration.

```nix
# packages/claude-code/sandbox.nix
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
  # MCP servers configuration
  mcpServers = {
    docs-rs-mcp = {
      type = "stdio";
      command = sandbox.docs-rs-mcp |> lib.getExe;
      args = [];
      env = {};
    };
    mcp-server-browser = {
      type = "stdio";
      command = sandbox.mcp-server-browser |> lib.getExe;
      args = [];
      env = {};
    };
    godot-mcp = {
      type = "stdio";
      command = sandbox.godot-mcp |> lib.getExe;
      args = [];
      env = {};
    };
  };

  nixpakPackage = mkNixpakPackage {
    config = {sloth, ...}: let
      workingDir = sloth.env "NIXPAK_WORKING_DIRECTORY";
    in {
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
          "PATH" = sloth.concat [
            (sloth.env "PATH")
            ":"
            (lib.makeBinPath [coreutils direnv nix findutils bash gawk])
          ];
          "SSL_CERT_FILE" = "/etc/ssl/certs/ca-bundle.crt";
          "SHELL" = sloth.env "SHELL";
        };

        bind.rw = [
          # Working directory (passed from wrapper)
          (sloth.env "NIXPAK_WORKING_DIRECTORY")
          # Claude config
          (sloth.concat' sloth.homeDir "/.claude")
          (sloth.concat' sloth.homeDir "/.claude.json")
          (sloth.concat' sloth.homeDir "/.claude.json.backup")
          (sloth.concat' sloth.xdgCacheHome "/claude-cli-nodejs")
          # Nix/Direnv integration
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
          # Inject MCP config into working directory
          [
            ((writeTextFile {
                name = ".mcp.json";
                text = builtins.toJSON { inherit mcpServers; };
              }) |> toString)
            (sloth.concat' workingDir "/.mcp.json")
          ]
        ];

        # Required for terminal raw mode
        sharePgid = true;
      };
    };
  };
in
  writeShellScriptBin "claude-code" ''
    export NIXPAK_WORKING_DIRECTORY="$(pwd)"

    if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
      export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
    fi

    ${nixpakPackage |> lib.getExe} "$@"
  ''
```

---

## MCP Server with Browser

### mcp-server-browser

MCP server that controls a sandboxed browser.

```nix
# packages/mcp-server-browser/sandbox.nix
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
    ${nixpakPackage |> lib.getExe} \
      --executable-path ${sandbox.ungoogled-chromium |> lib.getExe} \
      "$@"
  ''
```

---

## Patterns

### Wrapper Script Pattern

For applications needing environment setup:

```nix
let
  nixpakPackage = mkNixpakPackage { ... };
in
  writeShellScriptBin "app-name" ''
    # Environment setup
    export MY_VAR="value"

    # Dynamic CA support
    if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
      export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
    fi

    # Pass working directory
    export NIXPAK_WORKING_DIRECTORY="$(pwd)"

    ${nixpakPackage |> lib.getExe} "$@"
  ''
```

### Separate Module Pattern

For complex configs, create a separate module:

```nix
# packages/my-app/nixpak-module.nix
{sloth, ...}: {
  bubblewrap.bind.rw = [
    (sloth.concat' sloth.xdgConfigHome "/my-app")
  ];
}
```

```nix
# packages/my-app/sandbox.nix
{...}:
mkNixpakPackage {
  config = {...}: {
    imports = [
      ./nixpak-module.nix
    ];
  };
}
```

### Composing Sandboxed Applications

Reference other sandboxed packages:

```nix
{sandbox, ...}:
# Use sandbox.other-app instead of other-app
let
  browserPath = sandbox.ungoogled-chromium |> lib.getExe;
in
  # Pass to your app
```

---

## Registration Checklist

After creating a sandbox:

1. Add package definition (if new):
   ```nix
   # packages/default.nix overlay
   my-app = self.callPackage ./my-app {};
   ```

2. Add sandbox:
   ```nix
   # packages/default.nix sandbox section
   sandbox.my-app = self.callPackage ./my-app/sandbox.nix {
     inherit mkNixpakPackage nixpakModules;
   };
   ```

3. Export in flake (if needed):
   ```nix
   # flake.nix
   packages.${system} = { inherit (pkgs) my-app; };
   ```

4. Build and test:
   ```bash
   git add packages/my-app
   nix build .#sandbox.my-app
   ./result/bin/my-app --help
   ```

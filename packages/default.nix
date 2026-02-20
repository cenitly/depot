{
  nixpkgs,
  system,
  nixpak,
  rust-overlay,
  godot-mcp,
  ...
}: let
  pkgs = (import nixpkgs) {
    inherit system config;
    overlays = [
      (import rust-overlay)
    ];
  };
  inherit (pkgs) lib;
  allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];
  config = {
    inherit allowUnfreePredicate;
  };

  rust = pkgs.rust-bin.stable.latest.default.override {
    targets = [
      "x86_64-unknown-linux-gnu"
      "x86_64-pc-windows-msvc"
    ];
    extensions = [];
  };

  mkNixpakPackage = args: let
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
    pkg = mkNixPak args;
  in
    pkg.config.env;
  nixpakModules = import ./nixpak-modules;
in
  (import nixpkgs) {
    inherit system;
    overlays = [
      (
        self: _: {
          claude-code = (self.callPackage ./claude-code {}) // {
            wrapped = self.callPackage ./claude-code/wrapped.nix {};
          };
          docs-rs-mcp = self.callPackage ./docs-rs-mcp {};
          eslint-mcp = self.callPackage ./eslint-mcp {};
          ghidra-mcp = self.callPackage ./ghidra-mcp {};
          lucide-icons-mcp = self.callPackage ./lucide-icons-mcp {};
          mcp-server-browser = self.callPackage ./mcp-server-browser {};
          svelte-mcp = self.callPackage ./svelte-mcp {};
          tailwindcss-mcp-server = self.callPackage ./tailwindcss-mcp-server {};
          sandbox = {
            claude-code = self.callPackage ./claude-code/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            docs-rs-mcp = self.callPackage ./docs-rs-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            eslint-mcp = self.callPackage ./eslint-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            figma-linux = self.callPackage ./figma-linux/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            ghidra = (self.callPackage ./ghidra/sandbox.nix {inherit mkNixpakPackage nixpakModules;}) // {
              wrapped = self.callPackage ./ghidra/wrapped.nix {inherit mkNixpakPackage nixpakModules;};
            };
            ghidra-mcp = self.callPackage ./ghidra-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            godot-mcp = self.callPackage ./godot-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules godot-mcp;};
            lucide-icons-mcp = self.callPackage ./lucide-icons-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            mcp-server-browser = self.callPackage ./mcp-server-browser/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            svelte-mcp = self.callPackage ./svelte-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            tailwindcss-mcp-server = self.callPackage ./tailwindcss-mcp-server/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            ungoogled-chromium = self.callPackage ./ungoogled-chromium/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
          };
        }
      )
    ];
    inherit config;
  }

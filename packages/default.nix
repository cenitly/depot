{
  nixpkgs,
  system,
  nixpak,
  rust-docs-mcp-server,
  rust-overlay,
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
          rust-docs-mcp-server = self.callPackage ./rust-docs-mcp-server {inherit rust-docs-mcp-server rust;};
          docs-rs-mcp = self.callPackage ./docs-rs-mcp {};
          mcp-server-browser = self.callPackage ./mcp-server-browser {};
          sandbox = {
            rust-docs-mcp-server = self.callPackage ./rust-docs-mcp-server/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            claude-code = self.callPackage ./claude-code/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            docs-rs-mcp = self.callPackage ./docs-rs-mcp/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            mcp-server-browser = self.callPackage ./mcp-server-browser/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
            ungoogled-chromium = self.callPackage ./ungoogled-chromium/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
          };
        }
      )
    ];
    inherit config;
  }

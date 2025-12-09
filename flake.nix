{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpak = {
      url = "github:poly2it/nixpak?ref=share-pid";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    godot-mcp = {
      url = "github:poly2it/Godot-MCP?ref=fix-npm-deps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    pkgsFor = system: import ./packages (inputs // {inherit system;});
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = let
      lib = nixpkgs.lib;
    in
      f:
        systems
        |> lib.map (system: f system (pkgsFor system))
        |> lib.foldl (a: b: lib.recursiveUpdate a b) {};
    forAllSystemAttrs = f: forAllSystems (system: pkgs: {${system} = f system pkgs;});
    treefmtEval = forAllSystemAttrs (system: pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in
    forAllSystems (
      system: pkgs: {
        formatter = forAllSystemAttrs (system: pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
        checks = forAllSystemAttrs (
          system: pkgs: {
            formatting = treefmtEval.${pkgs.system}.config.build.check self;
          }
        );
        devShells.${system} = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              sops
            ];
          };
        };
        packages.${system} = {
          inherit
            (pkgs)
            docs-rs-mcp
            godot-mcp
            mcp-server-browser
            sandbox
            ;
        };
      }
    );
}

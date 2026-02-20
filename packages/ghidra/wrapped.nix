{
  mkNixpakPackage,
  nixpakModules,
  lib,
  writeShellScriptBin,
  xwayland,
  symlinkJoin,
  makeBinaryWrapper,
  ghidra,
  ghidra-mcp,
  ...
}: let
  ghidraWrapped = symlinkJoin {
    name = "ghidra-with-mcp-${ghidra.version}";
    paths = [ghidra-mcp.extension];
    nativeBuildInputs = [makeBinaryWrapper];
    postBuild = ''
      # Prevent attempted creation of plugin lock files in the Nix store
      touch $out/lib/ghidra/Ghidra/.dbDirLock

      makeWrapper '${ghidra}/bin/ghidra' "$out/bin/ghidra" \
        --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
      makeWrapper '${ghidra}/bin/ghidra-analyzeHeadless' "$out/bin/ghidra-analyzeHeadless" \
        --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
      ln -s ${ghidra}/share $out/share
    '';
    inherit (ghidra) meta;
  };
in
  import ./sandbox.nix {
    inherit mkNixpakPackage nixpakModules lib writeShellScriptBin xwayland;
    ghidra = ghidraWrapped;
  }

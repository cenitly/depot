{
  symlinkJoin,
  makeBinaryWrapper,
  ghidra,
  ghidra-mcp,
  ...
}:
symlinkJoin {
  name = "ghidra-with-mcp-${ghidra.version}";
  paths = [ghidra-mcp.extension];
  nativeBuildInputs = [makeBinaryWrapper];
  postBuild = ''
    # Prevent attempted creation of plugin lock files in the Nix store
    touch $out/lib/ghidra/Ghidra/.dbDirLock

    makeBinaryWrapper '${ghidra}/bin/ghidra' "$out/bin/ghidra" \
      --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
    makeBinaryWrapper '${ghidra}/bin/ghidra-analyzeHeadless' "$out/bin/ghidra-analyzeHeadless" \
      --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
    ln -s ${ghidra}/share $out/share
  '';
  inherit (ghidra) meta;
}

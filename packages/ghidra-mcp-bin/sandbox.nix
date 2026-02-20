{
  mkNixpakPackage,
  nixpakModules,
  ghidra-mcp-bin,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    imports = with nixpakModules; [
      network
    ];
    app.package = ghidra-mcp-bin;
  };
}

{
  mkNixpakPackage,
  nixpakModules,
  ghidra-mcp,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    imports = with nixpakModules; [
      network
    ];
    app.package = ghidra-mcp;
  };
}

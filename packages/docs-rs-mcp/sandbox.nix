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

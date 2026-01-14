{
  mkNixpakPackage,
  nixpakModules,
  lucide-icons-mcp,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = lucide-icons-mcp;
    imports = with nixpakModules; [
      network
    ];
  };
}

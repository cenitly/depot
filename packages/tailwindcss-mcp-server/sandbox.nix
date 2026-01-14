{
  mkNixpakPackage,
  nixpakModules,
  tailwindcss-mcp-server,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = tailwindcss-mcp-server;
    imports = with nixpakModules; [
      network
    ];
  };
}

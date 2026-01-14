{
  mkNixpakPackage,
  nixpakModules,
  svelte-mcp,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = svelte-mcp;
    imports = with nixpakModules; [
      network
    ];
  };
}

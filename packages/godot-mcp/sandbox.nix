{
  godot-mcp,
  mkNixpakPackage,
  nixpakModules,
  stdenv,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = godot-mcp.packages.${stdenv.hostPlatform.system}.default;
    imports = with nixpakModules; [
      network
    ];
  };
}

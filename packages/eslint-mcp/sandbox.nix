{
  mkNixpakPackage,
  nixpakModules,
  eslint-mcp,
  ...
}:
mkNixpakPackage {
  config = {sloth, ...}: {
    app.package = eslint-mcp;
    imports = with nixpakModules; [
      network
    ];
    # ESLint needs read access to lint files
    bubblewrap.bind.ro = [
      (sloth.env "NIXPAK_WORKING_DIRECTORY")
    ];
  };
}

{
  mkNixpakPackage,
  nixpakModules,
  figma-linux,
  lib,
  flatpak-xdg-utils,
  fetchFromGitHub,
  fetchNpmDeps,
  ...
}:
mkNixpakPackage {
  config = {sloth, ...}: {
    app.package = figma-linux;
    # app.package = figma-linux.overrideAttrs (self: super: rec {
    #   inherit (super) pname version;
    #   src = fetchFromGitHub {
    #     owner = "peff1235";
    #     repo = "figma-linux";
    #     rev = "a358f303e312f1323f1606862e76a4ff614f751c";
    #     hash = "sha256-Yn6kC0qkLnITffUZ7jZQZNRXkg8dtiim8PRWH/cMfRw=";
    #   };
    #   npmDepsHash = "sha256-EXjMoqrvo92ZVRQ6vqoKmWOz5IMhyCBZKKKac/CJX7A=";
    #   npmDeps = fetchNpmDeps {
    #     inherit src;
    #     name = "${pname}-${version}-npm-deps";
    #     hash = npmDepsHash;
    #   };
    #   makeCacheWritable = true;
    # });
    imports = with nixpakModules; [
      gui-base
      network
      private-tmp
    ];

    flatpak.appId = "com.figma.Figma";

    bubblewrap = {
      clearEnv = false;
      env = {
        "PATH" = sloth.concat [(sloth.env "PATH") ":" (lib.makeBinPath [flatpak-xdg-utils])];
      };

      bind.rw = [
        (sloth.concat' sloth.xdgPicturesDir "/figma")
        (sloth.concat' sloth.xdgPicturesDir "/Figma")
        (sloth.concat' sloth.xdgConfigHome "/figma-linux")
      ];
    };
  };
}

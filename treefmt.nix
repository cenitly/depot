{
  pkgs,
  lib,
  ...
}: {
  projectRootFile = "flake.nix";
  programs.alejandra.enable = true;
  programs.dos2unix.enable = true;
  programs.mdformat = {
    enable = true;

    package = pkgs.mdformat.withPlugins (
      plugins:
        with plugins; [
          mdformat-gfm
          mdformat-gfm-alerts
          mdformat-tables
          (mdformat-toc.overrideAttrs (self: super: {
            pytestCheckPhase = "true";
            doCheck = false;
            meta.broken = false;
          }))
        ]
    );
  };
  settings.formatter.mdformat = {
    includes = ["*.md" ".rules"];
    options = ["--wrap" "88" "--number"];
  };
}

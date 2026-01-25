{
  lib,
  stdenv,
  fetchurl,
  unzip,
  python3Packages,
  makeWrapper,
  ghidra,
  symlinkJoin,
  makeBinaryWrapper,
}:
let
  pname = "ghidra-mcp";
  version = "1.4";

  src = fetchurl {
    url = "https://github.com/LaurieWired/GhidraMCP/releases/download/${version}/GhidraMCP-release-1-4.zip";
    hash = "sha256-uBylJA/d5X6k6JkXDc2f3ubtKSRigMdCY6UJv8/H5zQ=";
  };

  # The Ghidra extension component (for use with ghidra.withExtensions)
  extension = stdenv.mkDerivation {
    pname = "${pname}-extension";
    inherit version src;

    nativeBuildInputs = [unzip];

    unpackPhase = ''
      unzip $src
      unzip GhidraMCP-release-1-4/GhidraMCP-1-4.zip
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/ghidra/Ghidra/Extensions
      cp -r GhidraMCP $out/lib/ghidra/Ghidra/Extensions/

      # Prevent attempted creation of plugin lock files in the Nix store
      touch $out/lib/ghidra/Ghidra/Extensions/GhidraMCP/.dbDirLock

      runHook postInstall
    '';

    meta = {
      description = "Ghidra extension that exposes program data via HTTP server for MCP integration";
      homepage = "https://github.com/LaurieWired/GhidraMCP";
      license = lib.licenses.asl20;
      platforms = lib.platforms.all;
    };
  };

  # Python dependencies for the MCP bridge
  pythonEnv = python3Packages.python.withPackages (ps: [
    ps.requests
    ps.mcp
  ]);
in
  # The MCP bridge (main package)
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [unzip makeWrapper];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib

      # Install the bridge script
      cp GhidraMCP-release-1-4/bridge_mcp_ghidra.py $out/lib/

      # Create wrapper with Python environment
      makeWrapper ${pythonEnv}/bin/python $out/bin/ghidra-mcp \
        --add-flags "$out/lib/bridge_mcp_ghidra.py"

      runHook postInstall
    '';

    passthru = {
      inherit extension;

      # Ghidra bundled with the MCP extension
      ghidraWithExtension = symlinkJoin {
        name = "ghidra-with-mcp-${ghidra.version}";
        paths = [extension];
        nativeBuildInputs = [makeBinaryWrapper];
        postBuild = ''
          # Prevent attempted creation of plugin lock files in the Nix store
          touch $out/lib/ghidra/Ghidra/.dbDirLock

          makeWrapper '${ghidra}/bin/ghidra' "$out/bin/ghidra" \
            --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
          makeWrapper '${ghidra}/bin/ghidra-analyzeHeadless' "$out/bin/ghidra-analyzeHeadless" \
            --set NIX_GHIDRAHOME "$out/lib/ghidra/Ghidra"
          ln -s ${ghidra}/share $out/share
        '';
        inherit (ghidra) meta;
      };
    };

    meta = {
      description = "MCP server for allowing LLMs to autonomously reverse engineer applications with Ghidra";
      homepage = "https://github.com/LaurieWired/GhidraMCP";
      license = lib.licenses.asl20;
      mainProgram = "ghidra-mcp";
      platforms = lib.platforms.all;
    };
  }

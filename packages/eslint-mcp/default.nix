{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
}: let
  pname = "eslint-mcp";
  version = "0.2.0";
in
  buildNpmPackage {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@eslint/mcp/-/mcp-${version}.tgz";
      hash = "sha256-0fJQe//mn3A2vZQi4EgUlKhWkd1xJWeWLapPM6nxN8k=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDeps = importNpmLock {
      npmRoot = ./.;
    };

    npmConfigHook = importNpmLock.npmConfigHook;

    dontNpmBuild = true;
    dontNpmPrune = true;

    # Create a symlink with a simple name since @eslint/mcp contains /
    postInstall = ''
      ln -s "$out/bin/@eslint/mcp" "$out/bin/eslint-mcp"
    '';

    meta = with lib; {
      description = "Official MCP server for ESLint - lint JavaScript/TypeScript code";
      homepage = "https://github.com/eslint/rewrite/tree/main/packages/mcp";
      license = licenses.asl20;
      mainProgram = "eslint-mcp";
    };
  }

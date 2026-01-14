{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
  nodejs,
}: let
  pname = "tailwindcss-mcp-server";
  version = "0.1.1";
in
  buildNpmPackage {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
      hash = "sha256-1Oux/H0eTKUL94fCTXV0JHu2WYLLWHkWVpiwvUU3e68=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      # Remove prepare script to prevent npm from trying to build during install
      ${lib.getExe' nodejs "node"} -e "
        const pkg = JSON.parse(require('fs').readFileSync('package.json'));
        delete pkg.scripts?.prepare;
        require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2));
      "
    '';

    npmDeps = importNpmLock {
      npmRoot = ./.;
    };

    npmConfigHook = importNpmLock.npmConfigHook;

    dontNpmBuild = true;
    dontNpmPrune = true;

    meta = with lib; {
      description = "MCP server for TailwindCSS utilities, documentation, and CSS conversion";
      homepage = "https://github.com/CarbonoDev/tailwindcss-mcp-server";
      license = licenses.mit;
      mainProgram = "tailwindcss-server";
    };
  }

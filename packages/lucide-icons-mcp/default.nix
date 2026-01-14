{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
  nodejs,
}: let
  pname = "lucide-icons-mcp";
  version = "0.1.37";
in
  buildNpmPackage {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
      hash = "sha256-p8dFVCGxyCClQtQljIo14EtrfIFEaD2nc2ubf1OBXMw=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      # Remove prepare script to prevent npm from trying to run husky during install
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
      description = "MCP server for Lucide icons - search and get usage examples";
      homepage = "https://github.com/seeyangzhi/lucide-icons-mcp";
      license = licenses.mit;
      mainProgram = "lucide-icons-mcp";
    };
  }

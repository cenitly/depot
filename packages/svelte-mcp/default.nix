{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
}: let
  pname = "svelte-mcp";
  version = "0.1.17";
in
  buildNpmPackage {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@sveltejs/mcp/-/mcp-${version}.tgz";
      hash = "sha256-eSbT9/q51qkHCrDziWCkIPQXJd6h0HE+nyL4AjAMlE4=";
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

    meta = with lib; {
      description = "The official Svelte MCP server for AI assistants";
      homepage = "https://github.com/sveltejs/mcp";
      license = licenses.mit;
      mainProgram = "svelte-mcp";
    };
  }

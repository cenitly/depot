{
  lib,
  buildNpmPackage,
  fetchurl,
}: let
  pname = "mcp-server-browser";
  version = "1.2.26";
in
  buildNpmPackage {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@agent-infra/${pname}/-/${pname}-${version}.tgz";
      hash = "sha256-YO5FIQiUbwzPyb7neu/gCI2KOvWiqC4HQDV6na+sNGE=";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-yOw5+KZTvfpToS6V5o2FHVxVBc9BEE582CiRNdceRU0=";

    dontNpmBuild = true;

    PUPPETEER_SKIP_DOWNLOAD = true;

    meta = with lib; {
      description = "Fast, lightweight MCP server for browser automation via Puppeteer";
      homepage = "https://github.com/bytedance/UI-TARS-desktop";
      license = licenses.asl20;
      mainProgram = pname;
    };
  }

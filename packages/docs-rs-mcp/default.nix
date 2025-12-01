{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "docs-rs-mcp";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "nuskey8";
    repo = "docs-rs-mcp";
    rev = "v${version}";
    hash = "sha256-fKtDrTPDDgRk6ssWLk79TkQ1KzaAIVLI0Vo9deleTjc=";
  };

  npmDepsHash = "sha256-IFhz3DfAyWQbnaW8dC7XLClfxeFbY4b9FuT/O+YRXkI=";

  dontNpmBuild = false;

  meta = with lib; {
    description = "MCP server for searching Rust crates and documentation from docs.rs";
    homepage = "https://github.com/nuskey8/docs-rs-mcp";
    license = licenses.mit;
    mainProgram = "docs-rs-mcp";
  };
}

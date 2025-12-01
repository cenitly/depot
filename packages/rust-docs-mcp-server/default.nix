{
  gcc,
  lib,
  pkg-config,
  rust,
  rust-docs-mcp-server,
  stdenv,
  writeShellScriptBin,
  ...
}:
writeShellScriptBin "rustdocs_mcp_server" ''
  export PATH="${lib.makeBinPath [pkg-config rust gcc]}"
  ${lib.getExe' rust-docs-mcp-server.packages.${stdenv.hostPlatform.system}.default "rustdocs_mcp_server"} "$@"
''

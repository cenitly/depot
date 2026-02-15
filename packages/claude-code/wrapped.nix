{
  claude-code,
  lib,
  sandbox,
  writeShellScriptBin,
  writeTextFile,
}: let
  mcpServers = import ./mcp-servers.nix {inherit lib sandbox;};
  mcpJson = writeTextFile {
    name = "mcp.json";
    text =
      {inherit mcpServers;}
      |> builtins.toJSON;
  };
in
  writeShellScriptBin "claude" ''
    exec ${claude-code |> lib.getExe} --mcp-config ${mcpJson} "$@"
  ''

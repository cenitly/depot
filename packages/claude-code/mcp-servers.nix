{
  lib,
  sandbox,
}: {
  docs-rs-mcp = {
    type = "stdio";
    command = sandbox.docs-rs-mcp |> lib.getExe;
    args = [];
    env = {};
  };
  mcp-server-browser = {
    type = "stdio";
    command = sandbox.mcp-server-browser |> lib.getExe;
    args = [];
    env = {};
  };
  svelte-mcp = {
    type = "stdio";
    command = sandbox.svelte-mcp |> lib.getExe;
    args = [];
    env = {};
  };
  eslint-mcp = {
    type = "stdio";
    command = sandbox.eslint-mcp |> lib.getExe;
    args = [];
    env = {};
  };
  lucide-icons-mcp = {
    type = "stdio";
    command = sandbox.lucide-icons-mcp |> lib.getExe;
    args = [
      "--stdio"
    ];
    env = {};
  };
  tailwindcss-mcp-server = {
    type = "stdio";
    command = sandbox.tailwindcss-mcp-server |> lib.getExe;
    args = [];
    env = {};
  };
  ghidra-mcp = {
    type = "stdio";
    command = sandbox.ghidra-mcp |> lib.getExe;
    args = [];
    env = {};
  };
}

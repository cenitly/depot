{sloth, ...}: {
  bubblewrap = {
    bind.rw = [
      (sloth.concat' sloth.xdgDataHome "/rustdocs-mcp-server")
    ];
    env = {
      OPENAI_API_KEY = sloth.env "OPENAI_API_KEY";
    };
  };
}

# Depot

Nix flake for packaging and sandboxing applications, primarily MCP servers.

## Tech Stack

- **Nix Flakes** - Package management and reproducible builds
- **Nixpak** - Bubblewrap-based sandboxing framework
- **treefmt** - Code formatting (Nix, Markdown)

## Project Structure

```
packages/
├── default.nix          # Package overlay and sandbox registry
├── nixpak-modules/      # Reusable sandbox modules (network, gui-base, private-tmp)
├── <package>/
│   ├── default.nix      # Package definition
│   └── sandbox.nix      # Sandbox configuration
```

## Common Commands

- `nix build .#<package>` - Build a package
- `nix build .#sandbox.<package>` - Build sandboxed version
- `nix fmt` - Format all files
- `nix flake check` - Run checks

## Adding Packages

### NPM packages

Use the `/package-npm` skill or see @.claude/skills/package-npm/SKILL.md

Key points:

- Use `importNpmLock` (not `npmDepsHash`) - more idiomatic
- Fetch from npm registry with `fetchurl`
- Include `package.json` and `package-lock.json` (without devDependencies)
- Set `dontNpmBuild = true` and `dontNpmPrune = true` for pre-built packages

### Registering packages

1. Add to `packages/default.nix` overlay:

   ```nix
   <name> = self.callPackage ./<name> {};
   ```

2. Add sandbox to `packages/default.nix`:

   ```nix
   sandbox.<name> = self.callPackage ./<name>/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
   ```

3. Export in `flake.nix`:

   ```nix
   packages.${system} = { inherit (pkgs) <name>; };
   ```

## Sandbox Modules

Located in `packages/nixpak-modules/`:

- `network` - Network access + SSL certificates
- `gui-base` - GUI apps (Wayland, PulseAudio, GPU, fonts)
- `private-tmp` - Isolated /tmp directory

## Conventions

- Format with `nix fmt` before committing
- Sandbox MCP servers with minimal permissions (usually just `network`)
- Use `let/in` pattern for package definitions
- Add files to git before building (`git add`)


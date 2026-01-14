---
name: sandbox-nixpak
description: Create or update Nixpak sandbox configurations for applications. Use when the user asks to sandbox an application, create a sandbox.nix, or configure application isolation.
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch
---

# Nixpak Sandboxing

Nixpak is a declarative sandboxing framework wrapping bubblewrap for Nix packages.

## Quick Start

```nix
{
  mkNixpakPackage,
  nixpakModules,
  my-package,
  ...
}:
mkNixpakPackage {
  config = {sloth, ...}: {
    app.package = my-package;
    imports = with nixpakModules; [network];
  };
}
```

## Documentation Files

This skill contains detailed API documentation:

- @.claude/skills/sandbox-nixpak/BUBBLEWRAP.md - Bind mounts, sockets, environment, network
- @.claude/skills/sandbox-nixpak/SLOTH.md - Dynamic path helpers and variables
- @.claude/skills/sandbox-nixpak/DBUS.md - D-Bus policies and rules
- @.claude/skills/sandbox-nixpak/GPU.md - GPU access modes
- @.claude/skills/sandbox-nixpak/NETWORKING.md - Network and pasta configuration
- @.claude/skills/sandbox-nixpak/SYSTEM.md - Locale, timezone, SSL, fonts
- @.claude/skills/sandbox-nixpak/FLATPAK.md - Flatpak portal emulation
- @.claude/skills/sandbox-nixpak/WAYLAND.md - Wayland proxy configuration
- @.claude/skills/sandbox-nixpak/MODULES.md - This repository's reusable modules
- @.claude/skills/sandbox-nixpak/EXAMPLES.md - Comprehensive examples

## Module Structure

Nixpak uses NixOS-style module system. Core modules:

| Module | Purpose |
|--------|---------|
| `app` | Package and entrypoints |
| `bubblewrap` | Sandbox configuration |
| `dbus` | D-Bus access control |
| `gpu` | Graphics access |
| `pasta` | User-mode networking |
| `waylandProxy` | Wayland socket proxy |
| `flatpak` | Portal emulation |
| `fonts` | Font support |
| `locale` | Locale support |
| `timezone` | Timezone configuration |
| `etc` | System file configuration |

## Config Function Pattern

All sandbox configs follow this pattern:

```nix
mkNixpakPackage {
  config = {sloth, config, lib, pkgs, ...}: {
    # Configuration here
  };
}
```

The `config` function receives:
- `sloth` - Dynamic path helpers (see SLOTH.md)
- `config` - Current configuration (for self-reference)
- `lib` - Nixpkgs lib functions
- `pkgs` - Nixpkgs package set

## Registration in This Repo

1. Create `packages/<name>/sandbox.nix`
2. Add to `packages/default.nix`:
   ```nix
   sandbox.<name> = self.callPackage ./<name>/sandbox.nix {
     inherit mkNixpakPackage nixpakModules;
   };
   ```
3. Build: `nix build .#sandbox.<name>`

## Choosing Permissions

| App Type | Recommended |
|----------|-------------|
| CLI with network | `network` |
| MCP server | `network` |
| GUI app | `gui-base`, `network`, `private-tmp` |
| Browser | `gui-base`, `network`, `private-tmp` + custom binds |

**Principle**: Start minimal, add permissions as needed.

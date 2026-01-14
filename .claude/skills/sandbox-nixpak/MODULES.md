# Repository Modules

This repository provides reusable Nixpak modules in `packages/nixpak-modules/`.

## Available Modules

| Module | File | Purpose |
|--------|------|---------|
| `network` | `network.nix` | Network access with SSL |
| `gui-base` | `gui-base.nix` | Full GUI application support |
| `private-tmp` | `private-tmp.nix` | Isolated /tmp directory |

## Usage

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
    imports = with nixpakModules; [
      network
      gui-base
      private-tmp
    ];
  };
}
```

---

## network

**File:** `packages/nixpak-modules/network.nix`

Enables network access with proper SSL certificate handling.

### What it provides

```nix
{
  etc.sslCertificates.enable = lib.mkForce false;  # Uses custom impl
  bubblewrap = {
    network = true;
    bind.ro = [
      [caBundle "/etc/ssl/certs/ca-bundle.crt"]
      [caBundle "/etc/ssl/certs/ca-certificates.crt"]
      caBundle
    ];
  };
}
```

### Features

- Enables network access
- Mounts CA certificates to standard locations
- Supports `NIXPAK_SSL_CERTIFICATE` env var for custom CA bundles

### Environment Variable

Set `NIXPAK_SSL_CERTIFICATE` before launching to use a custom CA bundle:

```bash
export NIXPAK_SSL_CERTIFICATE="/path/to/ca-bundle.crt"
```

Useful for:
- Corporate proxies with custom CAs
- Dynamic CA bundles (e.g., `/run/dynamic-ca/`)

---

## gui-base

**File:** `packages/nixpak-modules/gui-base.nix`

Comprehensive GUI application support.

### What it provides

```nix
{
  dbus.policies = {
    "${config.flatpak.appId}" = "own";
    "${config.flatpak.appId}.*" = "own";
    "org.freedesktop.DBus" = "talk";
    "org.gtk.vfs.*" = "talk";
    "org.gtk.vfs" = "talk";
    "ca.desrt.dconf" = "talk";
    "org.freedesktop.portal.*" = "talk";
    "org.a11y.Bus" = "talk";
  };

  gpu.enable = lib.mkDefault true;
  gpu.provider = "bundle";

  fonts.enable = true;
  locale.enable = true;

  bubblewrap = {
    network = lib.mkDefault false;  # Must enable separately
    sockets = {
      wayland = true;
      pulse = true;
    };
    bind.rw = [
      # XDG cache mappings
      [sloth.appCacheDir sloth.xdgCacheHome]
      # Font/shader caches
      (sloth.concat' sloth.xdgCacheHome "/fontconfig")
      (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")
      (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache_db")
      (sloth.concat' sloth.xdgCacheHome "/radv_builtin_shaders")
      # Runtime directories
      (sloth.concat' sloth.runtimeDir "/at-spi/bus")
      (sloth.concat' sloth.runtimeDir "/gvfsd")
      (sloth.concat' sloth.runtimeDir "/dconf")
      (sloth.concat' sloth.runtimeDir "/doc")
    ];
    bind.ro = [
      # GTK config
      (sloth.concat' sloth.xdgConfigHome "/gtk-2.0")
      (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
      (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
      (sloth.concat' sloth.xdgConfigHome "/fontconfig")
      (sloth.concat' sloth.xdgConfigHome "/dconf")
    ];
    env = {
      XDG_DATA_DIRS = lib.makeSearchPath "share" [
        pkgs.adwaita-icon-theme
        pkgs.shared-mime-info
      ];
      XCURSOR_PATH = lib.concatStringsSep ":" [
        "${pkgs.adwaita-icon-theme}/share/icons"
        "${pkgs.adwaita-icon-theme}/share/pixmaps"
      ];
    };
  };
}
```

### Features

- D-Bus policies for GTK/portal integration
- GPU support (bundled Mesa)
- Fonts and locale
- Wayland and PulseAudio sockets
- GTK theme/icon support
- Shader cache persistence
- Accessibility support

### Note

Network is **disabled by default**. Add `network` module if needed:

```nix
imports = with nixpakModules; [gui-base network];
```

---

## private-tmp

**File:** `packages/nixpak-modules/private-tmp.nix`

Provides an isolated `/tmp` directory per sandbox instance.

### What it provides

```nix
{
  bubblewrap.bind.rw = [
    [
      (sloth.mkdir (sloth.concat [sloth.appCacheDir "/nixpak-tmp/"]))
      "/tmp"
    ]
    [
      (sloth.mkdir (sloth.concat [sloth.appCacheDir "/nixpak-tmp/"]))
      (sloth.envOr "TMP" (sloth.concat ["/tmp/nixpak-" sloth.instanceId]))
    ]
  ];
}
```

### Features

- Creates isolated `/tmp` backed by app cache directory
- Handles `TMP` environment variable
- Per-instance isolation using `sloth.instanceId`
- Prevents temp file conflicts between sandbox instances

### When to use

- Applications that write sensitive data to `/tmp`
- Multiple concurrent instances of same app
- Preventing temp file leaks to host

---

## Creating New Modules

To add a new reusable module:

1. Create `packages/nixpak-modules/my-module.nix`:

```nix
{sloth, config, lib, pkgs, ...}: {
  # Your configuration here
}
```

2. Register in `packages/nixpak-modules/default.nix`:

```nix
{
  gui-base = ./gui-base.nix;
  network = ./network.nix;
  private-tmp = ./private-tmp.nix;
  my-module = ./my-module.nix;  # Add here
}
```

3. Use in sandbox configs:

```nix
imports = with nixpakModules; [my-module];
```

---

## Module Combinations

### CLI with Network

```nix
imports = with nixpakModules; [network];
```

### GUI Application

```nix
imports = with nixpakModules; [gui-base network private-tmp];
```

### Isolated GUI (No Network)

```nix
imports = with nixpakModules; [gui-base private-tmp];
```

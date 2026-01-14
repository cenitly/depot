# GPU Configuration

Configure GPU/graphics access for sandboxed applications.

## Options

### gpu.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable GPU support |

```nix
gpu.enable = true;
```

### gpu.provider

| Property | Value |
|----------|-------|
| Type | `enum ["raw" "nixos" "bundle"]` |
| Default | `"nixos"` |
| Description | GPU driver provision method |

#### Provider: "raw"

Mounts GPU devices from `/dev/dri` directly. Simplest approach but requires host drivers to be compatible.

```nix
gpu = {
  enable = true;
  provider = "raw";
};
```

**Mounts:**
- `/dev/dri` (device)

#### Provider: "nixos"

Mounts the host's OpenGL driver from `/run/opengl-driver`. Works on NixOS systems.

```nix
gpu = {
  enable = true;
  provider = "nixos";
};
```

**Mounts:**
- `/run/opengl-driver` (read-only)
- `/dev/dri` (device)

#### Provider: "bundle"

Bundles a driver package with the application. Most portable but increases closure size.

```nix
gpu = {
  enable = true;
  provider = "bundle";
  bundlePackage = pkgs.mesa;
};
```

**Behavior:**
- Uses the specified `bundlePackage` for drivers
- Includes all necessary libraries in the sandbox

### gpu.bundlePackage

| Property | Value |
|----------|-------|
| Type | `package` |
| Default | `pkgs.mesa` |
| Description | Driver package when using bundle provider |

```nix
gpu = {
  enable = true;
  provider = "bundle";
  bundlePackage = pkgs.mesa;  # Default
};
```

## Common Configurations

### NixOS Desktop

```nix
gpu = {
  enable = true;
  provider = "nixos";
};
```

### Portable/Non-NixOS

```nix
gpu = {
  enable = true;
  provider = "bundle";
};
```

### No GPU (CLI apps)

```nix
gpu.enable = false;  # Default
```

## Integration with gui-base Module

This repository's `gui-base` module sets:

```nix
gpu.enable = lib.mkDefault true;
gpu.provider = "bundle";
```

This provides portable GPU support out of the box for GUI applications.

## Shader Cache

For GPU applications, you may want to persist shader caches:

```nix
bubblewrap.bind.rw = [
  (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")
  (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache_db")
  (sloth.concat' sloth.xdgCacheHome "/radv_builtin_shaders")  # AMD
];
```

The `gui-base` module includes these by default.

## Troubleshooting

### No GPU acceleration

1. Check `gpu.enable = true`
2. Try different providers: `"nixos"` → `"bundle"` → `"raw"`
3. Ensure `/dev/dri` devices exist on host

### Wrong driver version

Use `"bundle"` provider with explicit package:

```nix
gpu = {
  enable = true;
  provider = "bundle";
  bundlePackage = pkgs.mesa;
};
```

### Permission denied on /dev/dri

Ensure user is in `video` group on host, or the device permissions allow access.

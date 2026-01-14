# Wayland Proxy Configuration

Nixpak can proxy Wayland connections through `wayland-proxy-virtwl`, providing additional isolation and features like window title tagging.

## Overview

Instead of directly mounting the Wayland socket, the proxy:
- Intercepts Wayland protocol messages
- Can modify window properties
- Provides additional isolation layer
- Tags window titles for identification

## Options

### waylandProxy.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable proxied Wayland access |

```nix
waylandProxy.enable = true;
```

### waylandProxy.tag

| Property | Value |
|----------|-------|
| Type | `string` |
| Default | `"[${appName}] "` |
| Description | Prefix for window titles |

```nix
waylandProxy.tag = "[Sandboxed] ";
```

Window titles become: `[Sandboxed] Original Title`

### waylandProxy.args

| Property | Value |
|----------|-------|
| Type | `list of string` |
| Default | `["--tag=${config.waylandProxy.tag}"]` |
| Description | Arguments to wayland-proxy-virtwl |

```nix
waylandProxy.args = [
  "--tag=[MyApp] "
  "--verbose"
];
```

### waylandProxy.package

| Property | Value |
|----------|-------|
| Type | `package` |
| Default | `pkgs.wayland-proxy-virtwl` |
| Description | Wayland proxy package |

## Comparison: Direct vs Proxy

### Direct Socket (bubblewrap.sockets.wayland)

```nix
bubblewrap.sockets.wayland = true;
```

- Simpler setup
- Lower overhead
- No window tagging
- Less isolation

### Wayland Proxy

```nix
waylandProxy.enable = true;
```

- Additional isolation layer
- Window title tagging
- Can filter/modify protocol
- Slightly more overhead

## Common Configurations

### Simple GUI App (Direct)

```nix
bubblewrap.sockets.wayland = true;
```

### Tagged Windows (Proxy)

```nix
waylandProxy = {
  enable = true;
  tag = "[Sandbox] ";
};
```

### Custom Tag with App Name

```nix
waylandProxy = {
  enable = true;
  tag = "[${config.flatpak.appId}] ";
};
```

## Integration with gui-base

This repository's `gui-base` module uses direct socket mounting:

```nix
bubblewrap.sockets.wayland = true;
```

To use the proxy instead, override in your sandbox config:

```nix
imports = with nixpakModules; [gui-base network];

bubblewrap.sockets.wayland = false;  # Disable direct
waylandProxy.enable = true;          # Enable proxy
```

## X11 Note

For X11 applications, use:

```nix
bubblewrap.sockets.x11 = true;
```

There is no X11 proxy equivalent in Nixpak. X11 is inherently less secure than Wayland.

## Troubleshooting

### Windows not appearing

1. Check Wayland compositor is running
2. Verify `WAYLAND_DISPLAY` is set on host
3. Try direct socket first to isolate proxy issues

### No window tags

Ensure `waylandProxy.tag` is set and proxy is enabled.

### Performance issues

Try direct socket mounting instead of proxy:

```nix
waylandProxy.enable = false;
bubblewrap.sockets.wayland = true;
```

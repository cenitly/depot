# Bubblewrap Configuration

Complete reference for `bubblewrap.*` options in Nixpak.

## Network & IPC

### bubblewrap.network

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `true` |
| Description | Network access in the sandbox |

```nix
bubblewrap.network = false;  # Disable network access
```

### bubblewrap.shareIpc

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Share host IPC namespace |

```nix
bubblewrap.shareIpc = true;  # Share IPC with host
```

## Path Binding

### bubblewrap.bind.rw

| Property | Value |
|----------|-------|
| Type | `list of (path or [source dest])` |
| Default | `[]` |
| Description | Read-write paths to bind-mount |

```nix
bubblewrap.bind.rw = [
  # Simple path (same source and dest)
  "/path/to/dir"

  # Source-dest pair
  ["/host/path" "/sandbox/path"]

  # With sloth for dynamic paths
  (sloth.concat' sloth.xdgConfigHome "/myapp")

  # Create directory and bind
  [
    (sloth.mkdir (sloth.concat' sloth.appDataDir "/data"))
    (sloth.concat' sloth.xdgDataHome "/myapp")
  ]
];
```

### bubblewrap.bind.ro

| Property | Value |
|----------|-------|
| Type | `list of (path or [source dest])` |
| Default | `[]` |
| Description | Read-only paths to bind-mount |

```nix
bubblewrap.bind.ro = [
  "/etc/resolv.conf"
  (sloth.concat' sloth.homeDir "/.gitconfig")
  ["/host/config" "/app/config"]
];
```

### bubblewrap.bind.dev

| Property | Value |
|----------|-------|
| Type | `list of (path or [source dest])` |
| Default | `[]` |
| Description | Device paths to bind-mount |

```nix
bubblewrap.bind.dev = [
  "/dev/dri"      # GPU devices
  "/dev/input"    # Input devices
];
```

## Nix Store

### bubblewrap.bindEntireStore

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `true` |
| Description | Bind entire /nix/store read-only |

```nix
bubblewrap.bindEntireStore = true;
```

### bubblewrap.extraStorePaths

| Property | Value |
|----------|-------|
| Type | `list of package` |
| Default | `[]` |
| Description | Extra store paths to bind (when bindEntireStore=false) |

```nix
bubblewrap.extraStorePaths = [ pkgs.cacert pkgs.bash ];
```

## Tmpfs

### bubblewrap.tmpfs

| Property | Value |
|----------|-------|
| Type | `list of path` |
| Default | `[]` |
| Description | Paths to mount as tmpfs |

```nix
bubblewrap.tmpfs = [ "/tmp" "/run" ];
```

## Sockets

### bubblewrap.sockets.wayland

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Mount active Wayland socket |

### bubblewrap.sockets.x11

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Mount all X11 sockets |

### bubblewrap.sockets.pulse

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Mount PulseAudio socket |

### bubblewrap.sockets.pipewire

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Mount first PipeWire socket |

```nix
bubblewrap.sockets = {
  wayland = true;
  pulse = true;
  pipewire = false;
  x11 = false;
};
```

## API Virtual Filesystems

### bubblewrap.apivfs.proc

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `true` |
| Description | Mount /proc API VFS |

### bubblewrap.apivfs.dev

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `true` |
| Description | Mount /dev API VFS |

```nix
bubblewrap.apivfs = {
  proc = true;
  dev = true;
};
```

## Environment Variables

### bubblewrap.clearEnv

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Clear all inherited environment variables |

When `false` (default): All environment variables from the parent process are inherited. The `env` option only overrides or adds variables.

When `true`: Start with empty environment. Must explicitly set all variables the app needs.

```nix
bubblewrap.clearEnv = true;  # Start with clean environment
```

### bubblewrap.env

| Property | Value |
|----------|-------|
| Type | `attrs of (null or string or sloth)` |
| Default | `{}` |
| Description | Environment variables to set or override |

**Note:** These override or add to inherited variables (when `clearEnv = false`), or define the complete environment (when `clearEnv = true`).

```nix
bubblewrap.env = {
  # Static value
  "MY_VAR" = "value";

  # From host environment
  "TERM" = sloth.env "TERM";

  # With fallback
  "EDITOR" = sloth.envOr "EDITOR" "vim";

  # Dynamic path
  "HOME" = sloth.homeDir;

  # Concatenated
  "PATH" = sloth.concat [
    (sloth.env "PATH")
    ":"
    (lib.makeBinPath [pkgs.coreutils])
  ];

  # Unset (null removes variable)
  "UNWANTED_VAR" = null;
};
```

## Process Control

### bubblewrap.newSession

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Create new session (setsid). Protects against TTY escape attacks. |

```nix
bubblewrap.newSession = true;
```

### bubblewrap.dieWithParent

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Kill sandbox when parent process dies |

```nix
bubblewrap.dieWithParent = true;
```

### bubblewrap.sharePgid

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Share process group ID with parent. Required for terminal apps. |

```nix
# For terminal applications that need raw mode
bubblewrap.sharePgid = true;
```

## Package

### bubblewrap.package

| Property | Value |
|----------|-------|
| Type | `package` |
| Default | `pkgs.bubblewrap` |
| Description | Bubblewrap package to use |

```nix
bubblewrap.package = pkgs.bubblewrap;
```

## Common Patterns

### Minimal CLI Application

```nix
bubblewrap = {
  network = true;
  clearEnv = false;
};
```

### GUI Application

```nix
bubblewrap = {
  network = true;
  sockets = {
    wayland = true;
    pulse = true;
  };
  bind.rw = [
    (sloth.concat' sloth.xdgConfigHome "/myapp")
    (sloth.concat' sloth.xdgCacheHome "/myapp")
  ];
};
```

### Highly Isolated

```nix
bubblewrap = {
  network = false;
  clearEnv = true;
  newSession = true;
  dieWithParent = true;
  env = {
    "HOME" = sloth.homeDir;
    "PATH" = lib.makeBinPath [pkgs.coreutils];
  };
};
```

### Terminal Application

```nix
bubblewrap = {
  clearEnv = false;
  sharePgid = true;  # Required for raw terminal mode
  env = {
    "TERM" = sloth.env "TERM";
  };
};
```

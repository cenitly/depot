# Sloth - Dynamic Path Helpers

Sloth values enable dynamic path resolution at runtime. They are "extraordinarily lazy" - evaluation is delayed until the sandbox actually runs.

## Accessing Sloth

Sloth is available via module arguments:

```nix
mkNixpakPackage {
  config = {sloth, ...}: {
    # Use sloth here
  };
}
```

## Environment Functions

### sloth.env

Get an environment variable from the host.

```nix
sloth.env "VARIABLE_NAME"
```

**Examples:**
```nix
bubblewrap.env = {
  "TERM" = sloth.env "TERM";
  "SHELL" = sloth.env "SHELL";
  "USER" = sloth.env "USER";
  "DISPLAY" = sloth.env "DISPLAY";
};
```

### sloth.envOr

Get an environment variable with a fallback value.

```nix
sloth.envOr "VARIABLE_NAME" "default_value"
```

**Examples:**
```nix
bubblewrap.env = {
  "EDITOR" = sloth.envOr "EDITOR" "nano";
  "PAGER" = sloth.envOr "PAGER" "less";
};

bubblewrap.bind.rw = [
  (sloth.envOr "XDG_DOWNLOAD_DIR" (sloth.concat' sloth.homeDir "/Downloads"))
];
```

## String Functions

### sloth.concat

Concatenate multiple values into a single string.

```nix
sloth.concat [value1 value2 value3 ...]
```

**Examples:**
```nix
# Build PATH
bubblewrap.env."PATH" = sloth.concat [
  (sloth.env "PATH")
  ":"
  "/extra/bin"
];

# Build complex path
bubblewrap.bind.rw = [
  (sloth.concat [sloth.appCacheDir "/nixpak-tmp/" sloth.instanceId])
];
```

### sloth.concat'

Binary concatenation (two values only). Convenience for simple cases.

```nix
sloth.concat' value1 value2
```

**Examples:**
```nix
bubblewrap.bind.rw = [
  (sloth.concat' sloth.homeDir "/.config")
  (sloth.concat' sloth.xdgConfigHome "/myapp")
  (sloth.concat' sloth.xdgCacheHome "/myapp")
];
```

## Directory Functions

### sloth.mkdir

Create a directory specification. Used when you need to ensure a directory exists before binding.

```nix
sloth.mkdir path
```

**Examples:**
```nix
bubblewrap.bind.rw = [
  # Create app data dir and bind to config location
  [
    (sloth.mkdir (sloth.concat' sloth.appDataDir "/profile"))
    (sloth.concat' sloth.xdgConfigHome "/chromium")
  ]

  # Create temp directory
  [
    (sloth.mkdir (sloth.concat [sloth.appCacheDir "/nixpak-tmp/"]))
    "/tmp"
  ]
];
```

## Pre-defined Path Variables

### User Directories

| Variable | Typical Value | Description |
|----------|---------------|-------------|
| `sloth.homeDir` | `/home/user` | User's home directory |

### XDG Base Directories

| Variable | Typical Value | Description |
|----------|---------------|-------------|
| `sloth.xdgCacheHome` | `~/.cache` | User cache directory |
| `sloth.xdgConfigHome` | `~/.config` | User configuration directory |
| `sloth.xdgDataHome` | `~/.local/share` | User data directory |
| `sloth.xdgStateHome` | `~/.local/state` | User state directory |
| `sloth.runtimeDir` | `/run/user/1000` | Runtime directory |

### XDG User Directories

| Variable | Typical Value | Description |
|----------|---------------|-------------|
| `sloth.xdgDesktopDir` | `~/Desktop` | Desktop directory |
| `sloth.xdgDocumentsDir` | `~/Documents` | Documents directory |
| `sloth.xdgDownloadDir` | `~/Downloads` | Downloads directory |
| `sloth.xdgMusicDir` | `~/Music` | Music directory |
| `sloth.xdgPicturesDir` | `~/Pictures` | Pictures directory |
| `sloth.xdgPublicShareDir` | `~/Public` | Public share directory |
| `sloth.xdgTemplatesDir` | `~/Templates` | Templates directory |
| `sloth.xdgVideosDir` | `~/Videos` | Videos directory |

### Application Directories

| Variable | Description |
|----------|-------------|
| `sloth.appDir` | Application's sandbox root directory |
| `sloth.appCacheDir` | Application's cache directory |
| `sloth.appConfigDir` | Application's config directory |
| `sloth.appDataDir` | Application's data directory |

### Instance

| Variable | Description |
|----------|-------------|
| `sloth.instanceId` | Unique identifier for this sandbox instance |

## Common Patterns

### Application Config Directory

```nix
bubblewrap.bind.rw = [
  (sloth.concat' sloth.xdgConfigHome "/myapp")
];
```

### Multiple App Directories

```nix
bubblewrap.bind.rw = [
  (sloth.concat' sloth.xdgConfigHome "/myapp")
  (sloth.concat' sloth.xdgCacheHome "/myapp")
  (sloth.concat' sloth.xdgDataHome "/myapp")
];
```

### Downloads Access

```nix
bubblewrap.bind.rw = [
  (sloth.envOr "XDG_DOWNLOAD_DIR" (sloth.concat' sloth.homeDir "/Downloads"))
];
```

### Profile Directory with Creation

```nix
bubblewrap.bind.rw = [
  [
    (sloth.mkdir (sloth.concat' sloth.appDataDir "/profile"))
    (sloth.concat' sloth.xdgConfigHome "/browser")
  ]
];
```

### Environment Overrides

**Note:** When `clearEnv = false` (the default), all environment variables from the parent process are inherited. The `env` block only **overrides or adds** variables, it does not select which ones to expose.

```nix
bubblewrap = {
  clearEnv = false;  # All parent env vars inherited (default)
  env = {
    # Override HOME to use sandbox-aware path
    "HOME" = sloth.homeDir;

    # Extend PATH with additional packages
    "PATH" = sloth.concat [
      (sloth.env "PATH")
      ":"
      (lib.makeBinPath extraPackages)
    ];

    # Add new variable
    "MY_APP_CONFIG" = "/etc/myapp";

    # Remove inherited variable (set to null)
    "UNWANTED_VAR" = null;
  };
};
```

### Clean Environment

To start with a clean environment and explicitly set only what's needed:

```nix
bubblewrap = {
  clearEnv = true;  # Clear all inherited env vars
  env = {
    # Must explicitly set everything the app needs
    "HOME" = sloth.homeDir;
    "USER" = sloth.env "USER";
    "TERM" = sloth.env "TERM";
    "SHELL" = sloth.env "SHELL";
    "PATH" = lib.makeBinPath [pkgs.coreutils];
  };
};
```

### Isolated Temp Directory

```nix
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
```

### Read Host Config Files

```nix
bubblewrap.bind.ro = [
  (sloth.concat' sloth.homeDir "/.gitconfig")
  (sloth.concat' sloth.homeDir "/.ssh")
  (sloth.concat' sloth.xdgConfigHome "/git")
];
```

## Notes

- Sloth values are **not** regular Nix strings - they're special delayed-evaluation types
- You can combine sloth values with regular strings in `sloth.concat`
- Use `sloth.concat'` for simple two-value concatenation
- Always use sloth for paths that depend on the runtime environment
- Pre-defined variables automatically handle XDG defaults and fallbacks

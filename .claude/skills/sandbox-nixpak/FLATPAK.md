# Flatpak Portal Emulation

Nixpak can emulate a Flatpak application, enabling access to XDG Desktop Portals without exposing the entire home directory.

## Overview

XDG Desktop Portals provide:
- File chooser dialogs (open/save)
- Screenshot/screencast
- Notifications
- Opening URLs
- Print dialogs
- And more...

By emulating Flatpak, Nixpak tricks `xdg-desktop-portal` into providing these services to your sandboxed app.

## Options

### flatpak.appId

| Property | Value |
|----------|-------|
| Type | `string` |
| Default | `"com.nixpak.${derivedName}"` |
| Description | Application ID for portal identification |

The app ID should follow reverse-DNS naming:

```nix
flatpak.appId = "com.example.MyApp";
```

Default derivation: If your package is named `my-app`, the default becomes `com.nixpak.MyApp`.

## How It Works

1. Nixpak creates a fake `.flatpak-info` file
2. This file identifies the app to `xdg-desktop-portal`
3. Portal services become available via D-Bus
4. File access goes through the Document Portal (no direct home access needed)

## D-Bus Integration

For portals to work, you need appropriate D-Bus policies:

```nix
flatpak.appId = "com.example.MyApp";

dbus.policies = {
  # Own your app's bus name
  "${config.flatpak.appId}" = "own";
  "${config.flatpak.appId}.*" = "own";

  # Talk to portals
  "org.freedesktop.portal.*" = "talk";
  "org.freedesktop.impl.portal.*" = "talk";

  # Core D-Bus
  "org.freedesktop.DBus" = "talk";
};
```

## Portal Services

Common portal interfaces:

| Portal | Purpose |
|--------|---------|
| `org.freedesktop.portal.FileChooser` | Open/save file dialogs |
| `org.freedesktop.portal.OpenURI` | Open URLs in browser |
| `org.freedesktop.portal.Notification` | Desktop notifications |
| `org.freedesktop.portal.Screenshot` | Screenshots |
| `org.freedesktop.portal.Screencast` | Screen recording |
| `org.freedesktop.portal.Print` | Printing |
| `org.freedesktop.portal.Settings` | Desktop settings (theme, etc.) |
| `org.freedesktop.portal.Documents` | Document portal for file access |

## Document Portal

The Document Portal allows apps to access files selected via file dialogs without direct filesystem access:

1. User opens file dialog
2. Selects a file
3. Portal provides a FUSE-mounted path the app can access
4. App reads/writes through that path
5. Portal handles actual filesystem operations

This means your app can open arbitrary files without bind-mounting the entire home directory.

## Common Configurations

### Basic Portal Support

```nix
flatpak.appId = "com.example.MyApp";

dbus.policies = {
  "${config.flatpak.appId}" = "own";
  "org.freedesktop.DBus" = "talk";
  "org.freedesktop.portal.*" = "talk";
};
```

### Full GTK App with Portals

```nix
flatpak.appId = "com.example.MyGtkApp";

dbus.policies = {
  # App identity
  "${config.flatpak.appId}" = "own";
  "${config.flatpak.appId}.*" = "own";

  # Core
  "org.freedesktop.DBus" = "talk";

  # Portals
  "org.freedesktop.portal.*" = "talk";
  "org.freedesktop.impl.portal.*" = "talk";

  # GTK integration
  "org.gtk.vfs" = "talk";
  "org.gtk.vfs.*" = "talk";
  "ca.desrt.dconf" = "talk";

  # Accessibility
  "org.a11y.Bus" = "talk";
};

# Document portal runtime directory
bubblewrap.bind.rw = [
  (sloth.concat' sloth.runtimeDir "/doc")
];
```

## Naming Conventions

App IDs should:
- Use reverse-DNS format: `com.company.AppName`
- Be unique to your application
- Match what's used in `.desktop` files (if any)

Examples:
- `org.mozilla.Firefox`
- `com.spotify.Client`
- `org.gnome.Calculator`
- `ai.claude.ClaudeCode`

## Limitations

- Requires `xdg-desktop-portal` running on host
- Some portal features depend on desktop environment
- Not all apps are portal-aware (may need direct file access instead)

## Troubleshooting

### Portals not working

1. Check `xdg-desktop-portal` is running on host
2. Verify D-Bus policies include portal services
3. Ensure `flatpak.appId` is set

### File dialogs don't work

1. Add `org.freedesktop.portal.FileChooser` to D-Bus policies
2. Ensure `/doc` runtime directory is mounted:
   ```nix
   bubblewrap.bind.rw = [
     (sloth.concat' sloth.runtimeDir "/doc")
   ];
   ```

### Wrong app name in portal dialogs

Check `flatpak.appId` matches your intended app identity.

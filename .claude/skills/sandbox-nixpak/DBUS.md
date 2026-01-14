# D-Bus Configuration

Nixpak uses xdg-dbus-proxy to filter D-Bus access, providing fine-grained control over which services the sandboxed application can communicate with.

## Options

### dbus.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `true` |
| Description | Enable D-Bus access via proxy |

```nix
dbus.enable = true;
```

### dbus.policies

| Property | Value |
|----------|-------|
| Type | `attrs of ("see" or "talk" or "own")` |
| Default | `{}` |
| Description | Bus name to policy mapping |

Policy levels:
- `"see"` - Can see the service exists
- `"talk"` - Can call methods and receive signals
- `"own"` - Can own the bus name

```nix
dbus.policies = {
  # Own your app's bus name
  "org.example.MyApp" = "own";
  "org.example.MyApp.*" = "own";

  # Talk to system services
  "org.freedesktop.DBus" = "talk";
  "org.freedesktop.portal.*" = "talk";
  "org.freedesktop.Notifications" = "talk";

  # Desktop integration
  "org.gtk.vfs" = "talk";
  "org.gtk.vfs.*" = "talk";
  "ca.desrt.dconf" = "talk";
  "org.a11y.Bus" = "talk";

  # See but not talk
  "org.freedesktop.login1" = "see";
};
```

### dbus.rules.call

| Property | Value |
|----------|-------|
| Type | `attrs of (list of string)` |
| Default | `{}` |
| Description | Fine-grained method call rules |

```nix
dbus.rules.call = {
  "org.freedesktop.portal.Desktop" = [
    "org.freedesktop.portal.FileChooser.*"
    "org.freedesktop.portal.OpenURI.*"
  ];
};
```

### dbus.rules.broadcast

| Property | Value |
|----------|-------|
| Type | `attrs of (list of string)` |
| Default | `{}` |
| Description | Fine-grained signal broadcast rules |

```nix
dbus.rules.broadcast = {
  "org.freedesktop.portal.Desktop" = [
    "org.freedesktop.portal.Request.Response"
  ];
};
```

### dbus.args

| Property | Value |
|----------|-------|
| Type | `list of string` |
| Default | `[]` |
| Description | Raw arguments to xdg-dbus-proxy |

```nix
dbus.args = [
  "--log"
];
```

## Common Policy Sets

### Minimal Desktop App

```nix
dbus.policies = {
  "org.freedesktop.DBus" = "talk";
  "org.freedesktop.portal.*" = "talk";
};
```

### GTK Application

```nix
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
```

### Full Desktop Integration

```nix
dbus.policies = {
  # App identity
  "${config.flatpak.appId}" = "own";
  "${config.flatpak.appId}.*" = "own";

  # Core D-Bus
  "org.freedesktop.DBus" = "talk";

  # Desktop portals
  "org.freedesktop.portal.*" = "talk";
  "org.freedesktop.impl.portal.*" = "talk";

  # GTK/GNOME
  "org.gtk.vfs" = "talk";
  "org.gtk.vfs.*" = "talk";
  "ca.desrt.dconf" = "talk";
  "org.gnome.SessionManager" = "talk";

  # Notifications
  "org.freedesktop.Notifications" = "talk";

  # Accessibility
  "org.a11y.Bus" = "talk";

  # System info (read-only)
  "org.freedesktop.login1" = "see";
  "org.freedesktop.UPower" = "see";
};
```

### Media Application

```nix
dbus.policies = {
  "${config.flatpak.appId}" = "own";
  "org.freedesktop.DBus" = "talk";
  "org.freedesktop.portal.*" = "talk";

  # Media controls
  "org.mpris.MediaPlayer2.${config.flatpak.appId}" = "own";

  # PipeWire/PulseAudio
  "org.freedesktop.ReserveDevice1.*" = "talk";
};
```

## Disabling D-Bus

For applications that don't need D-Bus:

```nix
dbus.enable = false;
```

## Notes

- Policies use glob patterns (`*` matches any suffix)
- The app ID from `flatpak.appId` is often used as the bus name
- Portal access (`org.freedesktop.portal.*`) enables file dialogs, notifications, etc.
- GTK apps typically need `org.gtk.vfs` and `ca.desrt.dconf`
- Use `"see"` for services you only need to check existence of
- Use `"talk"` for services you need to interact with
- Use `"own"` for bus names your app should register

# System Configuration

Configuration for locale, timezone, fonts, and system files.

## Locale

### locale.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable glibc locale support |

### locale.package

| Property | Value |
|----------|-------|
| Type | `package` |
| Default | `pkgs.glibcLocales.override { allLocales = true; }` |
| Description | Locale package |

```nix
locale = {
  enable = true;
  package = pkgs.glibcLocales;
};
```

When enabled, sets `LOCALE_ARCHIVE` environment variable pointing to the locale archive.

## Timezone

### timezone.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable timezone configuration |

### timezone.provider

| Property | Value |
|----------|-------|
| Type | `enum ["host" "bundle"]` |
| Default | `"host"` |
| Description | Timezone source |

- `"host"` - Mount host's `/etc/localtime`
- `"bundle"` - Use bundled tzdata package

### timezone.zone

| Property | Value |
|----------|-------|
| Type | `string` |
| Default | `"UTC"` |
| Description | Timezone (when provider is "bundle") |

### timezone.package

| Property | Value |
|----------|-------|
| Type | `package` |
| Default | `pkgs.tzdata` |
| Description | tzdata package |

```nix
# Use host timezone
timezone = {
  enable = true;
  provider = "host";
};

# Bundle specific timezone
timezone = {
  enable = true;
  provider = "bundle";
  zone = "Europe/London";
};
```

## Fonts

### fonts.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable font support |

### fonts.fonts

| Property | Value |
|----------|-------|
| Type | `list of package` |
| Default | (see below) |
| Description | Font packages to include |

Default fonts:
- `cantarell-fonts`
- `dejavu_fonts`
- `liberation_ttf`
- `gyre-fonts`
- `source-sans`
- `source-code-pro`
- `noto-fonts-color-emoji`

```nix
fonts = {
  enable = true;
  fonts = with pkgs; [
    cantarell-fonts
    dejavu_fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
  ];
};
```

When enabled:
- Generates fontconfig cache
- Mounts fonts read-only
- Configures `FONTCONFIG_FILE`

## SSL Certificates

### etc.sslCertificates.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable SSL/TLS certificate support |

### etc.sslCertificates.path

| Property | Value |
|----------|-------|
| Type | `path` |
| Default | `${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt` |
| Description | CA bundle path |

```nix
etc.sslCertificates = {
  enable = true;
  path = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
};
```

Mounts to:
- `/etc/ssl/certs/ca-bundle.crt`
- `/etc/ssl/certs/ca-certificates.crt`

**Note:** This repository's `network` module provides an alternative implementation with dynamic CA support via `NIXPAK_SSL_CERTIFICATE` environment variable.

## Common Configurations

### Full Desktop App

```nix
locale.enable = true;
timezone = {
  enable = true;
  provider = "host";
};
fonts.enable = true;
```

### Minimal CLI

```nix
# Usually none of these needed for CLI apps
```

### International App

```nix
locale.enable = true;
fonts = {
  enable = true;
  fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
  ];
};
```

## Integration with gui-base Module

This repository's `gui-base` module enables:

```nix
fonts.enable = true;
locale.enable = true;
```

With additional fontconfig cache directories for persistence.

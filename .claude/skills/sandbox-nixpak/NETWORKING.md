# Network Configuration

Nixpak provides two networking approaches: direct host networking and pasta user-mode networking.

## Basic Network Access

### bubblewrap.network

The simplest way to enable/disable network:

```nix
bubblewrap.network = true;   # Enable (default)
bubblewrap.network = false;  # Disable completely
```

When enabled, the sandbox shares the host's network namespace.

## Pasta - User-Mode Networking

Pasta provides isolated networking with optional NAT. Useful when you want network access but with more isolation than sharing the host namespace.

### pasta.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable pasta networking |

```nix
pasta.enable = true;
```

### pasta.mode

| Property | Value |
|----------|-------|
| Type | `enum ["transparent" "isolate"]` |
| Default | `"isolate"` |
| Description | Networking mode |

#### Mode: "transparent"

Provides network access that looks similar to host networking.

```nix
pasta = {
  enable = true;
  mode = "transparent";
};
```

#### Mode: "isolate"

Creates an isolated network with NAT. Default settings:
- IP: `192.168.1.100/24`
- Gateway/DNS: `192.168.1.1`
- MAC: `52:54:00:12:34:56`

```nix
pasta = {
  enable = true;
  mode = "isolate";
};
```

### pasta.args

| Property | Value |
|----------|-------|
| Type | `list of string` |
| Default | `[]` |
| Description | Extra arguments to pasta |

```nix
pasta = {
  enable = true;
  args = [
    "--dns" "8.8.8.8"
    "--mtu" "1500"
  ];
};
```

### pasta.package

| Property | Value |
|----------|-------|
| Type | `package` |
| Default | `pkgs.passt` (patched) |
| Description | Pasta package |

## SSL Certificates

For HTTPS access, applications need CA certificates.

### etc.sslCertificates.enable

| Property | Value |
|----------|-------|
| Type | `bool` |
| Default | `false` |
| Description | Enable SSL certificate support |

### etc.sslCertificates.path

| Property | Value |
|----------|-------|
| Type | `path` |
| Default | `${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt` |
| Description | Path to CA bundle |

```nix
etc.sslCertificates = {
  enable = true;
  path = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
};
```

This mounts the CA bundle to:
- `/etc/ssl/certs/ca-bundle.crt`
- `/etc/ssl/certs/ca-certificates.crt`

## This Repository's Network Module

The `network` module in `packages/nixpak-modules/network.nix` provides:

```nix
{
  sloth,
  pkgs,
  lib,
  ...
}: let
  defaultCaBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  caBundle = sloth.envOr "NIXPAK_SSL_CERTIFICATE" defaultCaBundle;
in {
  etc.sslCertificates.enable = lib.mkForce false;
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

Features:
- Enables network access
- Mounts CA certificates
- Supports `NIXPAK_SSL_CERTIFICATE` env var for custom CA bundles

Usage:
```nix
imports = with nixpakModules; [network];
```

## Common Configurations

### CLI Tool with HTTPS

```nix
imports = with nixpakModules; [network];
```

### No Network (Isolated)

```nix
bubblewrap.network = false;
```

### Isolated Network with Pasta

```nix
pasta = {
  enable = true;
  mode = "isolate";
};
bubblewrap.network = false;  # Pasta handles networking
```

### Custom CA Certificate

From wrapper script:
```bash
export NIXPAK_SSL_CERTIFICATE="/path/to/custom/ca.crt"
```

Or for dynamic CA (e.g., corporate proxies):
```bash
if [ -f "/run/dynamic-ca/ca-certificates.crt" ]; then
  export NIXPAK_SSL_CERTIFICATE="/run/dynamic-ca/ca-certificates.crt"
fi
```

## DNS Resolution

When using host networking, DNS uses host's `/etc/resolv.conf` automatically.

For pasta isolated mode, DNS defaults to `192.168.1.1`. Override with:

```nix
pasta = {
  enable = true;
  mode = "isolate";
  args = ["--dns" "8.8.8.8"];
};
```

---
name: package-npm
description: Package an NPM package from the npm registry for Nix using buildNpmPackage and importNpmLock. Use when the user asks to package, add, or create a Nix package for an npm package.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch
---

# Package NPM for Nix

This skill packages NPM packages from the npm registry using `buildNpmPackage` with `importNpmLock`.

## Steps

### 1. Research the package

First, get package info from the npm registry:

```bash
# Get package metadata
curl -s "https://registry.npmjs.org/<package-name>/latest" | jq '{name, version, dependencies, bin}'
```

Or use WebFetch on `https://registry.npmjs.org/<package-name>/latest`.

### 2. Create the package directory

```bash
mkdir -p packages/<package-name>
```

### 3. Generate package-lock.json

Download the tarball, create a minimal package.json with only production dependencies, and generate the lock file:

```bash
cd /tmp
rm -rf npm-extract && mkdir npm-extract && cd npm-extract

# Download and extract
curl -sL "https://registry.npmjs.org/<scope>/<name>/-/<name>-<version>.tgz" | tar xz --strip-components=1

# Remove devDependencies (they often contain unpublished packages)
jq 'del(.devDependencies)' package.json > tmp.json && mv tmp.json package.json

# Generate lock file
npm install --package-lock-only
```

Copy `package-lock.json` and a minimal `package.json` (with only `name`, `version`, `bin`, `dependencies`) to the package directory.

### 4. Calculate the source hash

```bash
nix-prefetch-url --type sha256 "https://registry.npmjs.org/<scope>/<name>/-/<name>-<version>.tgz"
# Convert to SRI format
nix hash convert --to sri --hash-algo sha256 <hash>
```

### 5. Create default.nix

Use `importNpmLock` instead of `npmDepsHash` - it's more idiomatic and doesn't require hash calculation:

```nix
{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
}: let
  pname = "<package-name>";
  version = "<version>";
in
  buildNpmPackage {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/<scope>/<name>/-/<name>-${version}.tgz";
      hash = "<sha256-hash>";
    };

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDeps = importNpmLock {
      npmRoot = ./.;
    };

    npmConfigHook = importNpmLock.npmConfigHook;

    dontNpmBuild = true;  # Package is pre-built
    dontNpmPrune = true;  # Avoid pruning issues with missing devDeps

    meta = with lib; {
      description = "<description>";
      homepage = "<homepage>";
      license = licenses.<license>;
      mainProgram = "<binary-name>";
    };
  }
```

### 6. Register the package

Add to `packages/default.nix` overlay:

```nix
<package-name> = self.callPackage ./<package-name> {};
```

Add to `flake.nix` exports:

```nix
packages.${system} = {
  inherit (pkgs)
    # ... existing packages
    <package-name>
    ;
};
```

### 7. Build and test

```bash
git add packages/<package-name>
nix build .#<package-name>
./result/bin/<binary-name> --help
```

## Creating a sandbox (optional)

If sandboxing is needed, create `sandbox.nix`:

```nix
{
  mkNixpakPackage,
  nixpakModules,
  <package-name>,
  ...
}:
mkNixpakPackage {
  config = {...}: {
    app.package = <package-name>;
    imports = with nixpakModules; [
      network  # If network access needed
      # Add other modules as needed
    ];
  };
}
```

Register in `packages/default.nix`:

```nix
sandbox = {
  # ... existing sandboxes
  <package-name> = self.callPackage ./<package-name>/sandbox.nix {inherit mkNixpakPackage nixpakModules;};
};
```

## Useful tools

### Hash calculation

- **nix-prefetch-url**: Calculate source tarball hash
  ```bash
  nix-prefetch-url "https://registry.npmjs.org/@scope/pkg/-/pkg-1.0.0.tgz"
  nix hash convert --to sri --hash-algo sha256 <hash>
  ```

- **prefetch-npm-deps**: Calculate `npmDepsHash` (only needed if not using `importNpmLock`)
  ```bash
  nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"
  ```

### Other Nix packaging tools

- **[nurl](https://github.com/nix-community/nurl)**: Generate fetcher calls from repository URLs with automatic hash calculation (useful for GitHub sources)
- **[nix-init](https://github.com/nix-community/nix-init)**: Generate full Nix packages from URLs (supports Rust, Python, Go - not npm)
- **[nix-prefetch](https://github.com/msteen/nix-prefetch)**: General-purpose prefetch tool for any fetcher

### Why use importNpmLock?

`importNpmLock` is preferred over `npmDepsHash` because:
- No hash calculation needed - uses integrity hashes already in `package-lock.json`
- Simpler updates - just regenerate the lock file
- More idiomatic modern Nix approach

## Common issues

- **ENOTCACHED errors**: Usually means devDependencies reference unpublished packages. Remove them from package.json before generating lock file.
- **npm prune failures**: Add `dontNpmPrune = true;`
- **Build failures**: For pre-built packages, add `dontNpmBuild = true;`

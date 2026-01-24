{
  mkNixpakPackage,
  nixpakModules,
  lib,
writeShellScriptBin,
xwayland,
ghidra,
  ...
}: let
  nixpakPackage = mkNixpakPackage {
    config = {sloth, ...}: {
      imports = with nixpakModules; [
        gui-base
        network
        private-tmp
      ];
      app.package = writeShellScriptBin "ghidra" ''
        export _JAVA_AWT_WM_NONREPARENTING=1
        exec ${lib.getExe ghidra} "$@"
      '';
      dbus.enable = false;
      bubblewrap = {
        # Java Swing requires X11.
        sockets.x11 = true;
        bind.rw = [
          [
            (sloth.env "NIXPAK_WORKING_DIRECTORY")
            (sloth.concat' sloth.homeDir "/project")
          ]
          [
            (sloth.concat' sloth.xdgStateHome "/ghidra/java")
            (sloth.concat' sloth.homeDir "/.java")
          ]
          [
            (sloth.concat' sloth.xdgCacheHome "/ghidra")
            (sloth.concat' sloth.homeDir "/.local/cache/ghidra")
          ]
          [
            (sloth.concat' sloth.xdgConfigHome "/ghidra")
            (sloth.concat' sloth.homeDir "/.config/ghidra")
          ]
        ];
      };
    };
  };
in
  writeShellScriptBin "ghidra" ''
    export NIXPAK_WORKING_DIRECTORY="$(pwd)"

    # Start XWayland if an X11 socket doesn't exist as it's needed for Java Swing apps on Wayland.
    XWAYLAND_PID=""
    if [ ! -S "/tmp/.X11-unix/X''${DISPLAY#:}" ]; then
      ${lib.getExe xwayland} ''${DISPLAY:-:0} -ac &
      XWAYLAND_PID=$!
      # Wait for X11 socket to appear
      for i in $(seq 1 50); do
        [ -S "/tmp/.X11-unix/X''${DISPLAY#:}" ] && break
        sleep 0.1
      done
    fi

    # Set `XAUTHORITY` if not set as Nixpak requires it for the x11 socket option.
    # We use the `-ac` mode so auth is disabled anyway.
    export XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}"

    cleanup() {
      [ -n "$XWAYLAND_PID" ] && kill "$XWAYLAND_PID" 2>/dev/null
    }
    trap cleanup EXIT

    ${nixpakPackage |> lib.getExe} "$@"
  ''

{sloth, ...}: let
in {
  bubblewrap = {
    bind.rw = [
      [
        (sloth.mkdir (sloth.concat [
          sloth.appDataDir
          "/profile"
        ]))
        (sloth.concat [
          sloth.xdgConfigHome
          "/chromium"
        ])
      ]
      (sloth.envOr "XDG_DOWNLOAD_DIR" (sloth.concat' sloth.homeDir "/Downloads"))
      (sloth.concat' sloth.homeDir "/.pki")
    ];
  };
}

{sloth, ...}: {
  bubblewrap = {
    bind.rw = [
      [
        (sloth.mkdir (sloth.concat [
          sloth.appCacheDir
          "/nixpak-tmp/"
        ]))
        "/tmp"
      ]
      [
        (sloth.mkdir (sloth.concat [
          sloth.appCacheDir
          "/nixpak-tmp/"
        ]))
        (sloth.envOr "TMP" (sloth.concat ["/tmp/nixpak-" sloth.instanceId]))
      ]
    ];
  };
}

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

{
  stdenv,
  lib,
  apps,
  reports,
  ...
}:
stdenv.mkDerivation {
  pname = "blinkasm";
  version = "0.0.1";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out

    # Copy all contents from the reports derivation to the output root
    cp -r ${reports}/* $out/

    # Copy each app binary to the output under its attribute name
    ${builtins.concatStringsSep "\n" (
      lib.mapAttrsToList (name: drv: "cp -f \"${drv.appimage}\" \"$out/${name}.AppImage\"") apps
    )}
  '';
}

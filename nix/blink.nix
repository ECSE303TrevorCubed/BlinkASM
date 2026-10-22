{
  stdenv,
  lib,
  ...
}:
stdenv.mkDerivation {
  pname = "blink_asm";
  version = "0.0.1";
  src = ../asm;
  meta = {
    mainProgram = "blink";
    description = "Blink an LED on GPIO22, written in pure ARM assembly";
    license = lib.licenses.gpl3Plus;
  };
}

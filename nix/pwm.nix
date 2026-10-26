{
  stdenv,
  lib,
  wiringpi,
  ...
}:
stdenv.mkDerivation {
  pname = "pwm_asm";
  version = "0.0.1";
  src = ../asm;
  buildInputs = [ wiringpi ];
  meta = {
    mainProgram = "pwm";
    description = "PWM for an an LED on GPIO18, written in pure ARM assembly";
    license = lib.licenses.gpl3Plus;
  };
}

BlinkASM — Blink an LED on the Raspberry Pi 3B in pure ARM assembly.

# Follow these steps to build the program:

## For the blinker:

1. Move directories to location of the repository root `cd ~/BlinkASM`

1. Assemble and link with the ARM cross toolchain
   `nix build .#packages.aarch64-linux.blink_asm` (built on the aarch64 remote builder:
   the result is a static 32-bit ARM binary for the Pi 3B, no libraries required)

1. Copy the binary to the Pi `scp ./result/bin/blink pi@<pi-ip>:~/`

1. Run it on the Pi `sudo ./blink`

## For the PWM dimming:

1. Move to the directory of the root of this repository `cd <...>/BlinkASM`

1. Build and link our packaged PWM assembly on the pi:
   `nix build .#packages.aarch64-linux.pwm_asm.appimage`

   - This will be built on any aarch64 compatible builder configured (or on the pi
     itself)
   - This build dynamically links wiring pi, so the resulting binary is NOT portable
   - Therefore, we package all dependencies as part of the AppImage pack

1. Copy the binary to the Pi `scp ./result pi@<pi-ip>:~/pwm_asm.AppImage`

1. Run it on the pi with `sudo ./pwm_asm.AppImage`

### Building without AppImage:

1. When building the pwm binary without bundling it as an AppImage, build with
   `nix build .#packages.aarch64-linux.pwm_asm` instead
   - Note, this build is NOT portable and cannot simply be `scp`'d across machines
     without copying the necessary dependencies as well

# Other nix targets:

- Compile the report `nix build .#packages.aarch64-linux.blink_report`
- Build binary + report bundle `nix build .#packages.aarch64-linux.ci`
- Dev shell with the cross assembler `nix develop`

# Notes:

- `blink.asm` (top level) is the pseudo-code from the assignment handout; `asm/blink.s`
  is the working GNU assembler implementation that gets built
- The LED is driven on BCM GPIO22; change `PIN22_BIT`/the `GPFSEL2` bit calculations in
  `asm/blink.s` to use another pin

BlinkASM — Blink an LED on the Raspberry Pi 3B in pure ARM assembly.

# Follow these steps to build the program:

0. Move directories to location of the repository root `cd ~/BlinkASM`

1. Assemble and link with the ARM cross toolchain
   `nix build .#packages.aarch64-linux.blink_asm` (built on the aarch64 remote builder:
   the result is a static 32-bit ARM binary for the Pi 3B, no libraries required)

1. Copy the binary to the Pi `scp ./result/bin/blink pi@<pi-ip>:~/`

1. Run it on the Pi `sudo ./blink`

# Other nix targets:

- Compile the report `nix build .#packages.aarch64-linux.blink_report`
- Build binary + report bundle `nix build .#packages.aarch64-linux.ci`
- Dev shell with the cross assembler `nix develop`

# Notes:

- `blink.asm` (top level) is the pseudo-code from the assignment handout; `asm/blink.s`
  is the working GNU assembler implementation that gets built
- The LED is driven on BCM GPIO22; change `PIN22_BIT`/the `GPFSEL2` bit calculations in
  `asm/blink.s` to use another pin

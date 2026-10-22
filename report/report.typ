= ECSE303 #box(width: 1fr)[#align(right)[Lab \#2]]

== Lab Partners: Justin Fossum, Trevor Nichols, Trevor Swan #box(width: 1fr)[#align(right)[Group \#11]]

=== Measurements and Results:

- The binary was cross-compiled on an x86_64 machine with
  `nix build .#blink_asm`, copied to the Pi 3B and run with `sudo ./blink`
- The LED blinked on and off, staying on for 500 milliseconds before turning
  off for 500 milliseconds, stopping after 10 cycles

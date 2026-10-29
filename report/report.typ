= ECSE303 #box(width: 1fr)[#align(right)[Lab \#4]]

== Lab Partners: Justin Fossum, Trevor Nichols, Trevor Swan #box(width: 1fr)[#align(right)[Group \#11]]

=== Assignment Statement and Objective(s):
The objective of this assignment is to explore low-level hardware control on the Raspberry Pi through the 32-bit ARM assembly language. This lab focuses on manipulating GPIO pins and utilizing PWM to dynamically control LED brightness. The GNU toolchain is used, including `gcc` and `gdb`, for development.

==== Summary of Contents
- *Part 1:* A freestanding assembly program (`asm/blink.s`) that maps the PGIO register space into user virtual memory via the `/dev/gpiomem` interface using raw Linux system calls. This part configures GPIO 22 as an output pin and toggles a connected LED on and off through 10 full on/off cycles. It concludes by cleaning up resources before exiting with the LED turned off.
- *Part 2:* A wiringPi-linked assembly program (`asm/pwm.s`) that interfaces with the Pi's PWM controller. This routine smoothly ramps LED brightness from 0 to 1024, pauses, and dims the LED back down from 1024 to 0. WiringPi is linked against for this part, and this is callable by assembly due to the consistent ABI. This program also terminates by ensuring the LED is turned off.

=== Methodology and Steps:
==== Hardware Configuration
The experimental setup consists of two separate LED test circuits.
- *Part 1:* An LED connected through a 220 $Omega$ resistor to the Pi's ground node and GPIO pin 22. GPIO 22 is a standard digital I/O pin capable of being driven `HIGH` (3.3V) or `LOW` (0V).
#image("hardware_configuration_part_1.jpeg", width: 80%)
- *Part 2:* An LED connected through a 220 $Omega$ resistor to the Pi's ground node and GPIO pin 18. GPIO 18 is connected to the Pi's on-chip hardware PWM channel 0 (`PWM0`) when configured in Alternate Function 5 (`ALT5`).
#image("hardware_configuration_part_2.jpeg", width: 80%)

These pin references can be found in our notes. We chose to go with hardware PWM over software PWM due to implementation complexity and risks with interfering with Linux's scheduler.

==== Part 1: Direct Memory-Mapped Register Access
This part of the assignment was authored from scratch (without linking against `libc`).
- We utilized `/dev/gpiomem` to observe the exposed 4096-byte GPIO register blocks in user space
  - We opened this file using the `SYS_open` system call (`r7 = 5`) with flags `O_RDWR | O_SYNC` (`0x101002`)
  - The file descriptor was mapped using `SYS_mmap2` (`r7 = 192`) requesting 4096 bytes (`MAP_LEN = 0x1000`), read/write protection (`PROT_READ | PROT_WRITE = 0x3`), shared mapping (`MAP_SHARED = 0x1`), and page offset 0.
  - Error detection checked if the returned address in `r0` was greater than or equal to `0xfffff000`
- `GPFSEL2` at offset `0x08` was used to prepare GPIO pin 22
  - Controls pins GPIO 20 through 29. Each pin occupies a 3-bit field. Pin 22 corresponds to bits 8:6 ($3 times (22 - 20) = 6$)
  - To configure pin 22 as an output, we followed a read-modify-write routine:
  ```arm
     ldr	r2, [r8, #GPFSEL2]		// load current value
  bic	r2, r2, #(0b111 << 6)		// clear the 3 bits for pin 22
  orr	r2, r2, #(0b001 << 6)		// set function = output
  str	r2, [r8, #GPFSEL2]		// write back
  ```
- `GPSET0` at offset `0x1c` allows us to write a 1 to bit 22 (`PIN22_BIT = 1 << 22`), driving the pin HIGH (3.3V) and turning the LED on
- `GPCLR0` at offset `0x28` allows us to write a 1 bit to pin 22, driving the pin LOW and turing the LED off
- Using write only registers for set and clear eliminates any potential races with the hardware
- We used the `SYS_nanosleep` system call (`r7 = 162`) for delays
  - A `struct timespec` was initialized in the `.data` section with `tv_sec = 0` and `tv_nsec = 500000000` (500,000,000 nanoseconds = 0.5 seconds)
  - Each iteration (up to 10 blinks) follows:
    - `str r9, [r8, #GPSET0]` turns the LED on
    - `nanosleep(&delay, NULL)` blocks for 500 ms
    - `str r9, [r8, #GPCLR0]` turns the LED off
    - `nanosleep(&delay, NULL)` blocks for 500 ms
    - `subs r6, r6, #1` decrements the counter
- We clean up all resources to prevent resource leaks before exiting:
  - The LED remains off at the end of the loop as `GPCLR0` was executed right before loop exit
  - Unmaps virtual memory using `SYS_munmap` (`r7 = 91`).
  - Closes the file descriptor using `SYS_close` (`r7 = 6`).
  - Exits cleanly with return code 0 via `SYS_exit` (`r7 = 1`).

==== Part 2: Hardware PWM LED Dimming
This part relies on libc and WiringPi to dim an LED using the Pi's PWM controller.
- The brightness of the LED is controller by switching the PWM rapidly between HIGH and LOW voltage. The apparent brightness we see if determined by the duty cycle
- We initially tried to implement this using raw asm with no `wiringPi` calls, but quickly ran into complexity with initialization and implementation details.
- We instead opted to use `wiringPi` to call their PWM functions to interface with the Pi's hardware PWM controller:
  - We followed the AAPCS calling convention which specifies arguments be passed in registers `r0` through `r3` and return values in register `r0`
- The general procedure was as follows:
  1. Saves callee-saved registers: `push {r4, r5, lr}`
  2. Calls `wiringPiSetup()` with error handling
  3. Ramp up by initializing a counter (`r4 = 0`) with bound (`r5 = 1024`), calling `pwmWrite(LedPin, r4)` every `delayMs = 10` ms, incrementing the counter by 1 each step until it reaches 1024.
  4. Ramp down by initializing the counter (`r4 = 1024`), calling `pwmWrite(LedPin, r4)` decrementing the counter every 10 ms
  5. Terminate the LED by calling `pwmWrite(LedPin, 0)` to guarantee the LED is fully extinguished

==== Debugging
We used `gdb` to debug our code.
- The GNU debugger was executed on the Pi with `sudo gdb ./blink`
- Breakpoints were established at `_start` and inside the blink loop:
```txt
(gdb) break _start
(gdb) break blink_loop
(gdb) run
```
- Registers could then be accepting by continuing execution with `c` via `print/x $rA` where A is the register number
  - Inspecting `r7` to verify syscall number 5 (`SYS_open`).
  - Inspecting `r0` after `svc #0` to ensure a positive file descriptor was returned.
  - Inspecting `r0` after `SYS_mmap2` (192) to verify virtual page allocation
- For `pwm.s`, GDB was used to monitor the duty cycle value in `r4`

=== Results and Observations:

==== Part 1 Results: Direct Register LED Blinking
- The binary was cross-compiled on an x86_64 machine with `nix build .#blink_asm`, copied to the Pi 3B and run with `sudo ./blink`
- The LED blinked on and off, staying on for 500 milliseconds before turning off for 500 milliseconds, stopping after 10 cycles
  - Each toggle lasted 1 second total
- The LED turned off after the 10th cycle and the program exited without error
  - We confirmed the exit code was zero by checking `echo $?`

==== Part 2 Results: Hardware PWM LED Dimming
- The binary was cross-compiled with `nix build .#blink_pwm`
- We observed the following output to the screen upon execution due to our `printf` calls:
```txt
Raspberry Pi wiringPi pwm test
Dimming LED...
PWM demo complete!
```
- The LED started fully off and slowly increased in brightness to a maximum level over about 10 seconds
- Upon reaching the maximum brightness, the `Dimming LED...` message printed and the duty cycle gradually decreased from 100% to 0% over about 10 seconds
- The were no perceived flickers in the result due to the high frequency of the hardware PWM module
- THe LED was confirmed to be completely off at the end of execution, and the resulting exit code was checked to be 0 with `echo $?`

==== GDB Verification Transcript
The below output is verbatim from the terminal based on a `gdb` interactive session debugging part 1:

```txt
(gdb) break _start
Breakpoint 1 at 0x10074: file blink.s, line 40.
(gdb) break blink_loop
Breakpoint 2 at 0x100d4: file blink.s, line 72.
(gdb) run
Starting program: /home0/303/group11/repos/BlinkASM/debug/blink

Breakpoint 1, _start () at blink.s:40
warning: Source file is more recent than executable.
40		ldr	r0, =gpiomem_path
(gdb) info registers r0 r1 r7
r0             0x0                 0
r1             0x0                 0
r7             0x0                 0
(gdb) nexti 3
43		svc	#0
(gdb) info registers r0 r1 r7
r0             0x11148             69960
r1             0x101002            1052674
r7             0x5                 5
(gdb) nexti
44		cmp	r0, #0
(gdb) info registers r0
r0             0x3                 3
(gdb) continue
Continuing.

Breakpoint 2, blink_loop () at blink.s:72
72		str	r9, [r8, #GPSET0]
(gdb) info registers r6 r8 r9
r6             0xa                 10
r8             0xf7fee000          4160675840
r9             0x400000            4194304
(gdb) x/xw $r8 + 0x08
0xf7fee008:	0x67706940
(gdb) continue
Continuing.

Breakpoint 2, blink_loop () at blink.s:72
72		str	r9, [r8, #GPSET0]
(gdb) info registers r6
r6             0x9                 9
(gdb) delete breakpoints
Delete all breakpoints, watchpoints, tracepoints, and catchpoints? (y or n) y
(gdb) continue
Continuing.
[Inferior 1 (process 6930) exited normally]
```

=== Conclusions:
==== Techniques Learned
- This lab taught us how to interface with device driver memory (`/dev/gpiomem`) to interact with GPIO pins on a Raspberry Pi.
- We also got to see an physical application of PWM in the form of changing the brightness of an LED.
- Both of these parts gave us practical debugging experience using `gdb`, showing how to inspect a program during its execution.
- Learned about the syscall IDs for ARM Linux EABI
- Designed and understood how PWM can be utilized to present a dimmable LED by changing the duty cycle over time.

==== Thoughts on the Assignment
- Operating at such a low level allowed us to see what exactly is going on when we use a library like `wiringPi` to toggle and LED on and off
- The PWM portion demonstrated the trade-offs of bare-metal register control, as it was difficult to get a proof of concept functioning without error. Utilizing a library like `wiringPi` for this task was not only easier but also showed how you can interact with ABI compatible C code from raw assembly language.
-

=== Demo:
The demo for this lab has been uploaded to youtube and can be found here:

#link("https://youtube.com/shorts/dedZNkVWrrI?feature=share")

=== Notes:
- GPIO pin layout:
```txt
+-----+-----+---------+------+---+---Pi 3B--+---+------+---------+-----+-----+
| BCM | wPi |   Name  | Mode | V | Physical | V | Mode | Name    | wPi | BCM |
+-----+-----+---------+------+---+----++----+---+------+---------+-----+-----+
|     |     |    3.3v |      |   |  1 || 2  |   |      | 5v      |     |     |
|   2 |   8 |   SDA.1 | ALT0 | 1 |  3 || 4  |   |      | 5v      |     |     |
|   3 |   9 |   SCL.1 | ALT0 | 1 |  5 || 6  |   |      | 0v      |     |     |
|   4 |   7 | GPIO. 7 |   IN | 0 |  7 || 8  | 1 | ALT5 | TxD     | 15  | 14  |
|     |     |      0v |      |   |  9 || 10 | 1 | ALT5 | RxD     | 16  | 15  |
|  17 |   0 | GPIO. 0 |   IN | 0 | 11 || 12 | 0 | IN   | GPIO. 1 | 1   | 18  |
|  27 |   2 | GPIO. 2 |   IN | 0 | 13 || 14 |   |      | 0v      |     |     |
|  22 |   3 | GPIO. 3 |   IN | 0 | 15 || 16 | 0 | IN   | GPIO. 4 | 4   | 23  |
|     |     |    3.3v |      |   | 17 || 18 | 0 | IN   | GPIO. 5 | 5   | 24  |
|  10 |  12 |    MOSI | ALT0 | 0 | 19 || 20 |   |      | 0v      |     |     |
|   9 |  13 |    MISO | ALT0 | 0 | 21 || 22 | 0 | IN   | GPIO. 6 | 6   | 25  |
|  11 |  14 |    SCLK | ALT0 | 0 | 23 || 24 | 1 | OUT  | CE0     | 10  | 8   |
|     |     |      0v |      |   | 25 || 26 | 1 | OUT  | CE1     | 11  | 7   |
|   0 |  30 |   SDA.0 |   IN | 1 | 27 || 28 | 1 | IN   | SCL.0   | 31  | 1   |
|   5 |  21 | GPIO.21 |   IN | 1 | 29 || 30 |   |      | 0v      |     |     |
|   6 |  22 | GPIO.22 |   IN | 1 | 31 || 32 | 0 | IN   | GPIO.26 | 26  | 12  |
|  13 |  23 | GPIO.23 |   IN | 0 | 33 || 34 |   |      | 0v      |     |     |
|  19 |  24 | GPIO.24 |   IN | 0 | 35 || 36 | 0 | IN   | GPIO.27 | 27  | 16  |
|  26 |  25 | GPIO.25 |   IN | 1 | 37 || 38 | 0 | IN   | GPIO.28 | 28  | 20  |
|     |     |      0v |      |   | 39 || 40 | 0 | IN   | GPIO.29 | 29  | 21  |
+-----+-----+---------+------+---+----++----+---+------+---------+-----+-----+
| BCM | wPi |   Name  | Mode | V | Physical | V | Mode | Name    | wPi | BCM |
+-----+-----+---------+------+---+---Pi 3B--+---+------+---------+-----+-----+
```
- Syscall Reference Table (ARM EABI):
  #align(center)[
    #table(
      columns: (1.5fr, 1fr, 3fr),
      inset: 6pt,
      align: (left, center, left),
      table.header([*Syscall Name*], [*r7 Value*], [*Purpose / Arguments*]),
      [`SYS_exit`], [`1`], [`r0 = exit_code`],
      [`SYS_open`], [`5`], [`r0 = path, r1 = flags, r2 = mode`],
      [`SYS_close`], [`6`], [`r0 = fd`],
      [`SYS_munmap`], [`91`], [`r0 = addr, r1 = length`],
      [`SYS_nanosleep`], [`162`], [`r0 = req (timespec*), r1 = rem`],
      [`SYS_mmap2`],
      [`192`],
      [`r0 = addr, r1 = len, r2 = prot, r3 = flags, r4 = fd, r5 = pgoff`],
    )
  ]
- Useful register offsets:
  - GPIO Base Address (Raspberry Pi 2 or later)	0x3F200000
  - GPIO map length					0xB4
  - GPFSEL0						0
  - GPFSEL1						1
  - GPFSEL2						2
  - GPFSEL3						3
  - GPFSET0						7
  - GPFCLR0						10
  - GPFLEV0						13
- Access to `/dev/gpiomem` is restricted to root of users in the `gpio` group
  - The output binaries must be run with `sudo`
- `WiringPi` requires `sudo` when accessing hardware PWM

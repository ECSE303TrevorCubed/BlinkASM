// pwm.s -- Hardware PWM dimming for an LED on GPIO18 (Physical Pin 12)
// Target: Raspberry Pi 3B (BCM2837, ARMv7-A 32-bit EABI)
//
// Notes:
// 1. Must be run as root (sudo ./pwm) to access /dev/mem.
// 2. Hardware PWM0 is on GPIO18 (Pin 12) or GPIO12 (Pin 32).
//    GPIO22 (used in Part 1) does NOT have hardware PWM capability.
//    Ensure the LED is connected to GPIO18!
// 3. If audio is enabled, snd_bcm2835 may claim the PWM clock.
//    If clock errors occur, disable audio in /boot/config.txt (dtparam=audio=off).

	.syntax	unified
	.arm
	.text

	// Syscalls (ARM Linux EABI)
	.equ	SYS_exit,	1
	.equ	SYS_open,	5
	.equ	SYS_close,	6
	.equ	SYS_munmap,	91
	.equ	SYS_nanosleep,	162
	.equ	SYS_mmap2,	192

	// Memory & File flags
	.equ	O_RDWR,		0x2
	.equ	O_SYNC,		0x101000
	.equ	PROT_RW,	0x3		// PROT_READ | PROT_WRITE
	.equ	MAP_SHARED,	0x1
	.equ	PAGE_LEN,	0x1000		// 4KB page

	// Physical page addresses (BCM2837 / Raspberry Pi 3B)
	// (Divide physical address by 4096 for mmap2 4KB page offset)
	.equ	PHYS_CM_PAGE,	(0x3F101000 >> 12)
	.equ	PHYS_GPIO_PAGE,	(0x3F200000 >> 12)
	.equ	PHYS_PWM_PAGE,	(0x3F20C000 >> 12)

	// Clock Manager offsets & masks
	.equ	CM_PWMCTL,	0xA0
	.equ	CM_PWMDIV,	0xA4
	.equ	CM_PASSWD,	(0x5A << 24)

	// GPIO Function Select 1 (controls GPIO 10 to 19)
	.equ	GPFSEL1,	0x04

	// PWM Controller register offsets
	.equ	PWM_CTL,	0x00
	.equ	PWM_STA,	0x04
	.equ	PWM_RNG1,	0x10
	.equ	PWM_DAT1,	0x14

	// PWM parameters
	.equ	PWM_PERIOD,	1024		// Range (1024 counts)
	.equ	STEP_SIZE,	16		// Increment per dimming step (64 steps)
	.equ	FADE_CYCLES,	10		// 10 fade cycles (matches Part 1's 10 toggles)

	.global	_start
_start:
	// Open /dev/mem (Requires root privileges)
	ldr	r0, =dev_mem
	ldr	r1, =(O_RDWR | O_SYNC)
	mov	r7, #SYS_open
	svc	#0
	cmp	r0, #0
	blt	fail
	mov	r4, r0				// r4 = /dev/mem fd

	// 1. Map Clock Manager (0x3F101000)
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	ldr	r5, =PHYS_CM_PAGE
	mov	r7, #SYS_mmap2
	svc	#0
	ldr	r1, =0xfffff000
	cmp	r0, r1
	bhs	fail
	mov	r8, r0				// r8 = CM mapped base

	// 2. Map GPIO Controller (0x3F200000)
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	ldr	r5, =PHYS_GPIO_PAGE
	mov	r7, #SYS_mmap2
	svc	#0
	ldr	r1, =0xfffff000
	cmp	r0, r1
	bhs	fail
	mov	r9, r0				// r9 = GPIO mapped base

	// 3. Map PWM Controller (0x3F20C000)
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	ldr	r5, =PHYS_PWM_PAGE
	mov	r7, #SYS_mmap2
	svc	#0
	ldr	r1, =0xfffff000
	cmp	r0, r1
	bhs	fail
	mov	r10, r0				// r10 = PWM mapped base

	// --- Step A: Stop PWM controller ---
	mov	r1, #0
	str	r1, [r10, #PWM_CTL]

	// --- Step B: Stop PWM Clock and wait for BUSY to drop ---
	// Write PASSWD + SRC=1 (ENAB=0) to stop the clock smoothly
	ldr	r1, =(CM_PASSWD | 0x01)
	str	r1, [r8, #CM_PWMCTL]

	// Wait with timeout for BUSY (bit 7) to clear
	mov	r2, #0x20000
wait_busy_stop:
	ldr	r1, [r8, #CM_PWMCTL]
	tst	r1, #(1 << 7)			// Check bit 7 (BUSY)
	beq	clock_stopped
	subs	r2, r2, #1
	bne	wait_busy_stop
clock_stopped:

	// --- Step C: Configure Clock Divisor (Div = 32) ---
	// 19.2 MHz / 32 = 600 kHz. With period 1024: PWM freq ~ 586 Hz.
	ldr	r1, =(CM_PASSWD | (32 << 12))	// DIVI in bits 23:12
	str	r1, [r8, #CM_PWMDIV]

	// --- Step D: Enable Clock with 19.2 MHz Oscillator (SRC=1) ---
	// SRC=1 (oscillator), ENAB=1 (Bit 4)
	ldr	r1, =(CM_PASSWD | 0x11)
	str	r1, [r8, #CM_PWMCTL]

	// Short delay to allow clock generator to stabilize
	mov	r2, #0x2000
wait_clk_delay:
	subs	r2, r2, #1
	bne	wait_clk_delay

	// --- Step E: Configure GPIO 18 as ALT5 (PWM0) ---
	// In GPFSEL1, GPIO 18 is bits 26:24. ALT5 is 0b010.
	ldr	r1, [r9, #GPFSEL1]
	bic	r1, r1, #(0b111 << 24)		// Clear bits 26:24
	orr	r1, r1, #(0b010 << 24)		// ALT5 = 0b010
	str	r1, [r9, #GPFSEL1]

	// --- Step F: Set PWM Range and Initial Duty Cycle ---
	mov	r1, #PWM_PERIOD			// Period count = 1024
	str	r1, [r10, #PWM_RNG1]

	mov	r1, #0				// Initial duty cycle = 0 (OFF)
	str	r1, [r10, #PWM_DAT1]

	// --- Step G: Enable PWM Channel 1 (Mark-Space Mode) ---
	// Bit 0 = PWEN1 (Enable Channel 1)
	// Bit 7 = MSEN1 (1 = Mark-Space mode, 0 = Balanced mode)
	// NOTE: Bit 5 is USEF1 (Use FIFO). MUST BE 0 so PWM reads from PWM_DAT1!
	mov	r1, #0x81			// (1 << 7) | (1 << 0)
	str	r1, [r10, #PWM_CTL]

	// --- Step H: Call Dynamic Dimming Routine ---
	bl	dim_led

	// --- Cleanup and Shutdown ---
	// 1. Turn off PWM controller
	mov	r1, #0
	str	r1, [r10, #PWM_CTL]

	// 2. Reset GPIO 18 to Input (safety)
	ldr	r1, [r9, #GPFSEL1]
	bic	r1, r1, #(0b111 << 24)		// 000 = Input
	str	r1, [r9, #GPFSEL1]

	// 3. Unmap pages
	mov	r0, r10
	mov	r1, #PAGE_LEN
	mov	r7, #SYS_munmap
	svc	#0

	mov	r0, r9
	mov	r1, #PAGE_LEN
	mov	r7, #SYS_munmap
	svc	#0

	mov	r0, r8
	mov	r1, #PAGE_LEN
	mov	r7, #SYS_munmap
	svc	#0

	// 4. Close /dev/mem
	mov	r0, r4
	mov	r7, #SYS_close
	svc	#0

	// Clean exit (status 0)
	mov	r0, #0
	mov	r7, #SYS_exit
	svc	#0

fail:
	mov	r0, #1
	mov	r7, #SYS_exit
	svc	#0

// ====================================================================
// dim_led: Dynamically fades the LED down and up across FADE_CYCLES.
//          Varies PWM_DAT1 between 1024 (100%) and 0 (0%).
// ====================================================================
	.type	dim_led, %function
dim_led:
	push	{r4-r7, lr}

	mov	r5, #FADE_CYCLES		// r5 = cycle loop counter
cycle_loop:
	// --- Ramp DOWN: Bright (1024) -> Dim (0) ---
	mov	r6, #PWM_PERIOD			// r6 = duty cycle value
fade_down:
	str	r6, [r10, #PWM_DAT1]		// Update hardware duty cycle
	ldr	r0, =step_delay			// Sleep ~15ms per step
	mov	r1, #0
	mov	r7, #SYS_nanosleep
	svc	#0
	subs	r6, r6, #STEP_SIZE
	bpl	fade_down

	// Ensure completely off at bottom of ramp
	mov	r1, #0
	str	r1, [r10, #PWM_DAT1]

	// --- Ramp UP: Dim (0) -> Bright (1024) ---
	mov	r6, #0
fade_up:
	str	r6, [r10, #PWM_DAT1]		// Update hardware duty cycle
	ldr	r0, =step_delay			// Sleep ~15ms per step
	mov	r1, #0
	mov	r7, #SYS_nanosleep
	svc	#0
	add	r6, r6, #STEP_SIZE
	cmp	r6, #PWM_PERIOD
	ble	fade_up

	subs	r5, r5, #1
	bne	cycle_loop

	// Turn off LED at conclusion
	mov	r1, #0
	str	r1, [r10, #PWM_DAT1]

	pop	{r4-r7, pc}

	.data
dev_mem:
	.asciz	"/dev/mem"

	// Delay between brightness steps (15 ms)
	.align	2
step_delay:
	.word	0				// tv_sec = 0
	.word	15000000			// tv_nsec = 15,000,000 ns (15 ms)

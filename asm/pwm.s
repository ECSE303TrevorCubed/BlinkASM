.syntax	unified
	.arm
	.text

	// Syscalls (ARM EABI)
	.equ	SYS_exit,	1
	.equ	SYS_open,	5
	.equ	SYS_close,	6
	.equ	SYS_nanosleep,	162
	.equ	SYS_mmap2,	192

	// Memory & File flags
	.equ	O_RDWR,		0x2
	.equ	O_SYNC,		0x101000
	.equ	PROT_RW,	0x3
	.equ	MAP_SHARED,	0x1
	.equ	PAGE_LEN,	0x1000

	// Peripheral base for RPi 2/3 (BCM2836/BCM2837): 0x3F000000
	// For RPi 4 (BCM2711), change 0x3F to 0xFE
	.equ	PHYS_CM_PAGE,	(0x3F101000 >> 12)
	.equ	PHYS_GPIO_PAGE,	(0x3F200000 >> 12)
	.equ	PHYS_PWM_PAGE,	(0x3F20C000 >> 12)

	// Clock Manager offsets
	.equ	CM_PWMCTL,	0xA0
	.equ	CM_PWMDIV,	0xA4
	.equ	CM_PASSWD,	(0x5A << 24)

	// GPIO offsets
	.equ	GPFSEL1,	0x04

	// PWM offsets
	.equ	PWM_CTL,	0x00
	.equ	PWM_RNG1,	0x10
	.equ	PWM_DAT1,	0x14

	.global	_start
_start:
	// Open /dev/mem
	ldr	r0, =dev_mem
	ldr	r1, =(O_RDWR | O_SYNC)
	mov	r7, #SYS_open
	svc	#0
	cmp	r0, #0
	blt	fail
	mov	r4, r0				// r4 = fd

	// -------------------------------------------------------------
	// 1. Map Clock Manager (0x3F101000)
	// ARM EABI sys_mmap2 args:
	// r0 = addr, r1 = len, r2 = prot, r3 = flags, [sp] = fd, [sp, #4] = pgoff
	// -------------------------------------------------------------
	ldr	r5, =PHYS_CM_PAGE
	push	{r4, r5}			// fd at sp, pgoff at sp+4
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	mov	r7, #SYS_mmap2
	svc	#0
	add	sp, sp, #8
	cmn	r0, #4096			// Check for error return (-1 to -4095)
	bhi	fail
	mov	r8, r0				// r8 = CM virtual base

	// -------------------------------------------------------------
	// 2. Map GPIO Controller (0x3F200000)
	// -------------------------------------------------------------
	ldr	r5, =PHYS_GPIO_PAGE
	push	{r4, r5}
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	mov	r7, #SYS_mmap2
	svc	#0
	add	sp, sp, #8
	cmn	r0, #4096
	bhi	fail
	mov	r9, r0				// r9 = GPIO virtual base

	// -------------------------------------------------------------
	// 3. Map PWM Controller (0x3F20C000)
	// -------------------------------------------------------------
	ldr	r5, =PHYS_PWM_PAGE
	push	{r4, r5}
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	mov	r7, #SYS_mmap2
	svc	#0
	add	sp, sp, #8
	cmn	r0, #4096
	bhi	fail
	mov	r10, r0				// r10 = PWM virtual base

	// --- Step A: Disable PWM ---
	mov	r1, #0
	str	r1, [r10, #PWM_CTL]

	// --- Step B: Stop PWM Clock and wait for BUSY to drop ---
	ldr	r1, =(CM_PASSWD | 0x01)		// KILL = 1
	str	r1, [r8, #CM_PWMCTL]
wait_busy:
	ldr	r1, [r8, #CM_PWMCTL]
	tst	r1, #(1 << 7)			// Bit 7 = BUSY
	bne	wait_busy

	// --- Step C: Set Clock Divisor (Div = 32 -> 19.2MHz / 32 = 600kHz) ---
	ldr	r1, =(CM_PASSWD | (32 << 12))
	str	r1, [r8, #CM_PWMDIV]

	// --- Step D: Enable Clock (SRC=1: 19.2MHz OSC, ENAB=1) ---
	ldr	r1, =(CM_PASSWD | 0x11)
	str	r1, [r8, #CM_PWMCTL]

	// --- Step E: Configure GPIO 18 as ALT5 (PWM0) ---
	ldr	r1, [r9, #GPFSEL1]
	bic	r1, r1, #(0b111 << 24)
	orr	r1, r1, #(0b010 << 24)		// ALT5
	str	r1, [r9, #GPFSEL1]

	// --- Step F: Set PWM Range ---
	mov	r1, #1024			// 1024 counts (~586 Hz PWM frequency)
	str	r1, [r10, #PWM_RNG1]

	// --- Step G: Enable PWM0 in Mark-Space Mode ---
	mov	r1, #0x21			// PWEN1=1, MSEN1=1
	str	r1, [r10, #PWM_CTL]

	// --- Dimming Sweep Routine ---
	// Fade up then down continuously
fade_loop:
	// Ramp up: 0 -> 1024
	mov	r6, #0
ramp_up:
	str	r6, [r10, #PWM_DAT1]
	bl	delay
	add	r6, r6, #8
	cmp	r6, #1024
	ble	ramp_up

	// Ramp down: 1024 -> 0
	mov	r6, #1024
ramp_down:
	str	r6, [r10, #PWM_DAT1]
	bl	delay
	subs	r6, r6, #8
	bge	ramp_down

	b	fade_loop

// 5ms delay using sys_nanosleep
delay:
	push	{r7, lr}
	ldr	r0, =timespec_delay
	mov	r1, #0
	mov	r7, #SYS_nanosleep
	svc	#0
	pop	{r7, pc}

fail:
	mov	r0, #1
	mov	r7, #SYS_exit
	svc	#0

	.data
dev_mem:
	.asciz	"/dev/mem"

timespec_delay:
	.word	0				// Seconds: 0
	.word	5000000				// Nanoseconds: 5ms
    .syntax	unified
	.arm
	.text

	// Syscalls (ARM EABI)
	.equ	SYS_exit,	1
	.equ	SYS_open,	5
	.equ	SYS_close,	6
	.equ	SYS_mmap2,	192

	// Memory & File flags
	.equ	O_RDWR,		0x2
	.equ	O_SYNC,		0x101000
	.equ	PROT_RW,	0x3
	.equ	MAP_SHARED,	0x1
	.equ	PAGE_LEN,	0x1000

	// Physical page addresses (divide by 4096 for mmap2 page offset)
	.equ	PHYS_CM_PAGE,	(0x3F101000 >> 12)
	.equ	PHYS_GPIO_PAGE,	(0x3F200000 >> 12)
	.equ	PHYS_PWM_PAGE,	(0x3F20C000 >> 12)

	// Clock Manager offsets & masks
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
	// Open /dev/mem (Requires root)
	ldr	r0, =dev_mem
	ldr	r1, =(O_RDWR | O_SYNC)
	mov	r7, #SYS_open
	svc	#0
	cmp	r0, #0
	blt	fail
	mov	r4, r0				// r4 = fd

	// 1. Map Clock Manager (0x3F101000)
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	ldr	r5, =PHYS_CM_PAGE
	mov	r7, #SYS_mmap2
	svc	#0
	mov	r8, r0				// r8 = CM mapped base

	// 2. Map GPIO Controller (0x3F200000)
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	ldr	r5, =PHYS_GPIO_PAGE
	mov	r7, #SYS_mmap2
	svc	#0
	mov	r9, r0				// r9 = GPIO mapped base

	// 3. Map PWM Controller (0x3F20C000)
	mov	r0, #0
	mov	r1, #PAGE_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	ldr	r5, =PHYS_PWM_PAGE
	mov	r7, #SYS_mmap2
	svc	#0
	mov	r10, r0				// r10 = PWM mapped base

	// --- Step A: Stop PWM controller ---
	mov	r1, #0
	str	r1, [r10, #PWM_CTL]

	// --- Step B: Stop PWM Clock and wait for BUSY to drop ---
	ldr	r1, =(CM_PASSWD | 0x01)		// KILL = 1
	str	r1, [r8, #CM_PWMCTL]
wait_busy:
	ldr	r1, [r8, #CM_PWMCTL]
	tst	r1, #(1 << 7)			// Check bit 7 (BUSY)
	bne	wait_busy

	// --- Step C: Configure Clock Divisor (Div = 32) ---
	ldr	r1, =(CM_PASSWD | (32 << 12))
	str	r1, [r8, #CM_PWMDIV]

	// --- Step D: Enable Clock with 19.2 MHz Oscillator (SRC=1) ---
	ldr	r1, =(CM_PASSWD | 0x11)		// SRC=1 (osc), ENAB=1
	str	r1, [r8, #CM_PWMCTL]

	// --- Step E: Configure GPIO 18 as ALT5 (PWM0) ---
	ldr	r1, [r9, #GPFSEL1]
	bic	r1, r1, #(0b111 << 24)		// Clear bits 26:24
	orr	r1, r1, #(0b010 << 24)		// ALT5 = 0b010
	str	r1, [r9, #GPFSEL1]

	// --- Step F: Set PWM Range and Data ---
	mov	r1, #1024			// Period count = 1024
	str	r1, [r10, #PWM_RNG1]

	mov	r1, #512			// 50% duty cycle = 512
	str	r1, [r10, #PWM_DAT1]

	// --- Step G: Enable PWM Channel 1 (Mark-Space Mode) ---
	// Bit 0 = PWEN1 (enable)
	// Bit 5 = MSEN1 (1 = Mark-Space algorithm, 0 = Balanced)
	mov	r1, #0x21
	str	r1, [r10, #PWM_CTL]

	// Exit cleanly; hardware continues running autonomously
	mov	r0, #0
	mov	r7, #SYS_exit
	svc	#0

fail:
	mov	r0, #1
	mov	r7, #SYS_exit
	svc	#0

	.data
dev_mem:
	.asciz	"/dev/mem"
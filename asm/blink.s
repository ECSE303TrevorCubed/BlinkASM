// blink.s -- Blink an LED on BCM GPIO22
//
// GPIO register offsets from the mapped page base:
//   GPFSEL2 = 0x08  (function select, pins 20-29; pin 22 -> bits 8:6)
//   GPSET0  = 0x1c  (set pins 0-31;   pin 22 -> bit 22)
//   GPCLR0  = 0x28  (clear pins 0-31; pin 22 -> bit 22)

	.syntax	unified
	.arm
	.text

	// open() flags
	.equ	O_RDWR,		0x2
	.equ	O_SYNC,		0x101000

	// mmap2() arguments
	.equ	PROT_RW,	0x3		// PROT_READ | PROT_WRITE
	.equ	MAP_SHARED,	0x1
	.equ	MAP_LEN,	0x1000		// one page

	// GPIO register offsets / pin mask
	.equ	GPFSEL2,	0x08
	.equ	GPSET0,		0x1c
	.equ	GPCLR0,		0x28
	.equ	PIN22_BIT,	(1 << 22)

	// syscall numbers (ARM EABI, passed in r7)
	.equ	SYS_exit,	1
	.equ	SYS_open,	5
	.equ	SYS_close,	6
	.equ	SYS_munmap,	91
	.equ	SYS_nanosleep,	162
	.equ	SYS_mmap2,	192

	.equ	BLINKS,		10		// number of on/off cycles

	.global	_start
_start:
	// fd = open("/dev/gpiomem", O_RDWR | O_SYNC)
	ldr	r0, =gpiomem_path
	ldr	r1, =(O_RDWR | O_SYNC)
	mov	r7, #SYS_open
	svc	#0
	cmp	r0, #0
	blt	fail
	mov	r4, r0				// r4 = fd

	// r8 = mmap(NULL, MAP_LEN, PROT_RW, MAP_SHARED, fd, 0)
	mov	r0, #0
	mov	r1, #MAP_LEN
	mov	r2, #PROT_RW
	mov	r3, #MAP_SHARED
	// r4 already holds the fd
	mov	r5, #0				// pgoffset 0: GPIO regs at page base
	mov	r7, #SYS_mmap2
	svc	#0
	ldr	r1, =0xfffff000			// errors are unsigned -errno
	cmp	r0, r1
	bhs	fail
	mov	r8, r0				// r8 = GPIO register base

	// ---- configure GPIO22 as an output (GPFSEL2 bits 8:6 = 001) ----
	ldr	r2, [r8, #GPFSEL2]		// load current value
	bic	r2, r2, #(0b111 << 6)		// clear the 3 bits for pin 22
	orr	r2, r2, #(0b001 << 6)		// set function = output
	str	r2, [r8, #GPFSEL2]		// write back

	mov	r6, #BLINKS			// r6 = loop counter
	mov	r9, #PIN22_BIT			// r9 = pin 22 mask
blink_loop:
	// ---- set the pin (LED on) ----
	str	r9, [r8, #GPSET0]
	ldr	r0, =delay
	mov	r1, #0
	mov	r7, #SYS_nanosleep
	svc	#0

	// ---- clear the pin (LED off) ----
	str	r9, [r8, #GPCLR0]
	ldr	r0, =delay
	mov	r1, #0
	mov	r7, #SYS_nanosleep
	svc	#0

	subs	r6, r6, #1
	bne	blink_loop

	// ---- release GPIO resources ----
	mov	r0, r8
	mov	r1, #MAP_LEN
	mov	r7, #SYS_munmap
	svc	#0

	mov	r0, r4
	mov	r7, #SYS_close
	svc	#0

	mov	r0, #0				// exit(0)
	mov	r7, #SYS_exit
	svc	#0

fail:
	mov	r0, #1				// exit(1)
	mov	r7, #SYS_exit
	svc	#0

	.data
gpiomem_path:
	.asciz	"/dev/gpiomem"

	// struct timespec { tv_sec = 0, tv_nsec = 500000000 }  ->  0.5 s
	.align	2
delay:
	.word	0
	.word	500000000

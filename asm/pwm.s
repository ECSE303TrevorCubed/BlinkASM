// pwm.s -- Hardware PWM LED dimming using WiringPi
// Target: Raspberry Pi (ARMv7-A 32-bit EABI)
//
// Notes:
// 1. WiringPi Pin 1 corresponds to BCM GPIO 18 (Physical Pin 12 on 40-pin header).
// 2. Compile with: gcc -Wall -g -o pwm pwm.s -lwiringPi
// 3. Must be run with root privileges: sudo ./pwm

        .syntax unified
        .arm

// ---------------------------------------
//       Data Section
// ---------------------------------------
        .data
        .balign 4
Intro:      .asciz  "Raspberry Pi wiringPi PWM test starting...\n"
ErrMsg:     .asciz  "wiringPiSetup failed! Aborting...\n"
DimMsg:     .asciz  "Dimming LED...\n"
DoneMsg:    .asciz  "PWM demonstration complete.\n"

LedPin:     .int    1           // WiringPi Pin 1 = BCM GPIO 18 (Physical Pin 12)
delayMs:    .int    5           // Delay in ms per step (5 ms * 1024 = ~5.1 s)
PWM_OUTPUT  =       2           // WiringPi constant for PWM mode

// ---------------------------------------
//       Code Section
// ---------------------------------------
        .text
        .global main
        .extern printf
        .extern wiringPiSetup
        .extern delay
        .extern pinMode
        .extern pwmWrite

main:
        push    {r4, r5, lr}    // Save callee-saved registers & return address

        // printf("Raspberry Pi wiringPi PWM test starting...\n");
        ldr     r0, =Intro
        bl      printf

        // if (wiringPiSetup() == -1) { exit(1); }
        bl      wiringPiSetup
        cmp     r0, #-1
        bne     init
        ldr     r0, =ErrMsg
        bl      printf
        mov     r0, #1
        b       done

init:
        // pinMode(LedPin, PWM_OUTPUT);
        ldr     r0, =LedPin
        ldr     r0, [r0]        // r0 = 1 (WiringPi Pin 1 / BCM 18)
        mov     r1, #PWM_OUTPUT // r1 = 2 (PWM_OUTPUT)
        bl      pinMode

        // ==========================================================
        // Phase 1: Ramp UP (0 -> 1024) - Brighten LED
        // ==========================================================
        mov     r4, #0          // r4 = duty cycle counter (i = 0)
        mov     r5, #1024       // r5 = upper limit
ramp_up:
        cmp     r4, r5
        bgt     start_dim

        // pwmWrite(LedPin, r4);
        ldr     r0, =LedPin
        ldr     r0, [r0]
        mov     r1, r4
        bl      pwmWrite

        // delay(delayMs);
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay

        add     r4, r4, #1
        b       ramp_up

        // ==========================================================
        // Phase 2: Ramp DOWN (1024 -> 0) - Dim LED
        // ==========================================================
start_dim:
        ldr     r0, =DimMsg
        bl      printf

        mov     r4, #1024       // r4 = 1024
ramp_down:
        cmp     r4, #0
        blt     finish

        // pwmWrite(LedPin, r4);
        ldr     r0, =LedPin
        ldr     r0, [r0]
        mov     r1, r4
        bl      pwmWrite

        // delay(delayMs);
        ldr     r0, =delayMs
        ldr     r0, [r0]
        bl      delay

        subs    r4, r4, #1
        bge     ramp_down

finish:
        // Ensure LED is turned off at completion
        ldr     r0, =LedPin
        ldr     r0, [r0]
        mov     r1, #0
        bl      pwmWrite

        ldr     r0, =DoneMsg
        bl      printf
        mov     r0, #0

done:
        pop     {r4, r5, pc}    // Restore registers & return to caller

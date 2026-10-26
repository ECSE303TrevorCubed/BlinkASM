// pwm.s -- Hardware PWM LED dimming using WiringPi
//
// - WiringPi Pin 1 corresponds to BCM GPIO 18
// - Must be run with root privileges: sudo ./pwm

        .syntax unified
        .arm

// ---------------------------------------
//       Data Section
// ---------------------------------------
        .data
        .balign 4
Intro:      .asciz  "Raspberry Pi wiringPi pwm test\n"
ErrMsg:     .asciz  "Setup didn't work... Aborting...\n"
DimMsg:     .asciz  "Dimming LED...\n"
DoneMsg:    .asciz  "PWM demo complete!\n"

LedPin:     .int    1           // WiringPi Pin 1 = BCM GPIO 18
delayMs:    .int    10
PWM_OUTPUT  =       2           // WiringPi constant for PWM mode

// ---------------------------------------
//       Code Section
// ---------------------------------------
        .text
        .global main
        .extern printf          // From libc.stdio
        .extern wiringPiSetup   // From wiringPi
        .extern delay           // From wiringPi
        .extern pinMode         // From wiringPi
        .extern pwmWrite        // From wiringPi

main:
        push    {r4, r5, lr}    // Save callee-saved registers & return address

        // printf(Intro)
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
        ldr     r0, [r0]        // r0 = 1
        mov     r1, #PWM_OUTPUT // r1 = 2
        bl      pinMode

        // Brighten LED (0 -> 1024)
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

        // Dim LED (1024 -> 0)
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

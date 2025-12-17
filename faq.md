# FAQ

While the demo content and example programs still in development, you can start learning to use this mod by examples.
... or join discord community on the page https://mods.factorio.com/mod/fcpu/discussion

## Tutorial videos

- Very good tutorials was made by [BLU12 Gaming](https://www.youtube.com/channel/UCfb9HEuH1Fhio4MDsgEMoeA), see his YouTube channel.
- [DocJade programmed a single assembler with fCPU to beat Factorio](https://www.youtube.com/watch?v=z-2_x7baynI).

## Example 1

It simply **enumerates signals from red input wire and copies them in availabler registers from reg1 to reg7.**
fCPU code:

```
clr
:loop
mod reg8 cnr
mod reg8 7
inc reg8
mov reg@8 red@8
sst reg8 reg@8
mov out1 reg8
jmp :loop
```

## Example 2 (complex system for train management by Cid0rz)

https://github.com/cid0rz/CTS-Cidorz-Train-System


## Example 3 (recursion)
```
clr
mov r1 10        ; n = 10
call :fib        ; fib(10)
hlt

; int fib(int n)
; r1 = n
; return r1
;
:fib
enter 0
    ble r1 1 :fib_base

    push r1
    ; fib(n-1)
    dec r1
    call :fib
    mov r2 r1     ; r2 = fib(n-1)
    pop r1

    push r2
    ; fib(n-2)
    sub r1 2
    call :fib
    pop r2

    ; fib(n) = fib(n-1) + fib(n-2)
    add r1 r2
:fib_base
leave
```
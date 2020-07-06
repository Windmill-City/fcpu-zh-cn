# TODO

### Убрать чтение выходных сигналов
```asm
clr
mov out mem1
add 1 mem1
mov mem1 out
clr mem1
jmp 2
```

### Отображать состояние контроллера
Использовать `first_signal`



# fASM

- **S**: **S**ignal (consists of **T**ype and **V**alue)
  - **T**: signal type
  - **V**: signal value, same as **C**

* **C**: integer constant [-2^31..2^31), same as **V**
* **M**: memory
* **I**: input wire (**R**ed, **G**reen)
* **O**: output wire

- **A**: instruction address
- **L**: instruction label

`...` - one or more, could be specified multiple times with space separator.  
`?` - optional, may be specified.  


## Common

### nop
No operation.

### clr
Clear all memory and output.

### clr reg...[**M**/**O**]
Clear specified registers.

### mov dst...[M/O] src[S/M/I]
Copy signal from source to destination.  
*dst... = src*

### ssv dst...[M] val[V/M/I]
Set signal value.  
*dst... = val*

### sst dst...[M] type[T/M/I]
Set signal type.  
*dst... = type*

### fir type[T/M/I]
### fig type[T/M/I]
Find type in red/green input wire.


## Swap

### swp mem1[M] mem2[M]
Swap signals in memory cells.  
### swpt mem1[M] mem2[M]
Swap signal types in memory cells.  
### swpv mem1[M] mem2[M]
Swap signal values in memory cells.  
### dig dst[M/I] num[C/M/I]
Get digit *num*ber from *dest*inatination and write to dst.  
*dst = dst / 10^num % 10*
### dis dst[M] num[C/M/I] val[C/M/I]
Set digit to *val*ue at *num*ber in *dest*inatination.  
*dst = dst + (val % 10 - dst / 10^num % 10) * 10^num*


## Arithmetic

### inc dst[M]
*dst = dst + 1*
### dec dst[M]
*dst = dst - 1*
### add dst[M] src[C/I/M]
*dst = dst + src*
### sub dst[M] src[C/I/M]
*dst = dst - src*
### mul dst[M] src[C/I/M]
*dst = dst * src*
### div dst[M] src[C/I/M]
*dst = dst / src*
### mod dst[M] src[C/I/M]
*dst = dst % src*
### pow dst[M] src[C/I/M]
*dst = dst ^ src*


## Bitwise

### band dst[M] src[C/I/M]
AND.  
*dst = dst & src*

### bor dst[M] src[C/I/M]
OR.  
*dst = dst | src*

### bxor dst[M] src[C/I/M]
XOR.  
*dst = dst ^ src*

### ban dst[M] src[C/I/M]
AND NOT.  
*dst = dst & ~src*

### bsl dst[M] src[C/I/M]
Shift left.  
*dst = dst << src*

### bsr dst[M] src[C/I/M]
Shift right.  
*dst = dst >> src*

### brl dst[M] src[C/I/M]
Rotate left.  
*dst = dst rot<< src*

### brr dst[M] src[C/I/M]
Rotate right.  
*dst = dst rot>> src*


## Testing operands values

### teq a[C/I/M] b[I/M]
Equal.  
*a == b*

### tne a[C/I/M] b[I/M]
Not equal.  
*a != b*

### tgt a[C/I/M] b[I/M]
Greater than.  
*a > b*

### tlt a[C/I/M] b[I/M]
Less than.  
*a < b*

### tge a[C/I/M] b[I/M]
Greater or equal than.  
*a >= b*

### tle a[C/I/M] b[I/M]
Less or equal than.  
*a <= b*


## Testing operands types

### tas a[T/I/M] b[I/M]
Types are same.  

### tad a[T/I/M] b[I/M]
Types are different.  


## Flow control

### jmp addr[C/A/L]
Jump to address or label.

### hlt
*Halt* program execution until it will be resumed by player or by *Run* signal from any **i**nput wire.

### slp cnt[C]
Sleep for specified ticks count.

### bkr cnt[C]
### bkg cnt[C]
Block until there are at least *cnt* red/green signals.

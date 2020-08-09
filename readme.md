# fASM

## Specs
* support blueprints
* support copy & paste
* support multiplayer
* 32 instructions for whole program
* 8 register which can store signal and value
* 50+ opcodes
* rich math instructions
* two input wires (Red, Green)
* two output wires (Red, Green) have same output signal and value
* cound be controlled through special input signals
* one tick = one instruction
* made for geeks


## Legend

- **S**, signal: **S**ignal (consists of **T**ype and **V**alue)
  - **T**, type: signal type
  - **V**, value: signal value, same as **C**

* **C**, value: integer constant [-2^31..2^31), same as **V**
* **R**, register: (reg1, reg2, ..., reg8)
* **I**, wire: input wire (**r**ed, **g**reen)
* **O**, wire: output wire

- **A**, address: instruction address
- **L**, label: instruction label

`...` - one or more, could be specified multiple times with space separator.  
`?` - optional, may be specified.  


## Opcodes
### Common

* `nop`  
  No operation.

* `clr`  
  Clear all memory and output.

* `clr` reg...[**R**/**O**]  
  Clear specified registers.

* `mov` dst...[**R**/**O**] src[**V**/**T**/**S**/**R**/**I**]  
  Copy signal from source to destination.  
  *dst... = src*

* `out` src[**V**/**T**/**S**/**R**/**I**]  
  Copy signal from source to output.  
  Same as `mov out src`.  

* `ssv` dst...[**R**] val[**V**/**S**/**R**/**I**]  
  Set signal value.  
  *dst... = val*

* `sst` dst...[**R**] type[**T**/**S**/**R**/**I**]  
  Set signal type.  
  *dst... = type*

* `fir` dst[**R**/**O**] type[**T**/**R**/**I**]  
  `fig` dst[**R**/**O**] type[**T**/**R**/**I**]  
  Find type in red/green input wire.


### Swap

* `swp` reg1[**R**] reg2[**R**]  
  Swap signals in memory cells.
* `swpt` reg1[**R**] reg2[**R**]  
  Swap signal types in memory cells.
* `swpv` reg1[**R**] reg2[**R**]  
  Swap signal values in memory cells.


### Arithmetic

* `add` dst[**R**] src[**C**/**R**/**I**]  
  *dst = dst + src*
* `sub` dst[**R**] src[**C**/**R**/**I**]  
  *dst = dst - src*
* `mul` dst[**R**] src[**C**/**R**/**I**]  
  *dst = dst * src*
* `div` dst[**R**] src[**C**/**R**/**I**]  
  *dst = dst / src*
* `mod` dst[**R**] src[**C**/**R**/**I**]  
  *dst = dst % src*
* `pow` dst[**R**] src[**C**/**R**/**I**]  
  *dst = dst ^ src*

* `inc` dst[**R**]  
  *dst = dst + 1*
* `dec` dst[**R**]  
  *dst = dst - 1*

* `subi` dst[**R**] src[**C**/**R**/**I**]  
  *dst = src - dst*
* `divi` dst[**R**] src[**C**/**R**/**I**]  
  *dst = src / dst*
* `modi` dst[**R**] src[**C**/**R**/**I**]  
  *dst = src % dst*
* `powi` dst[**R**] src[**C**/**R**/**I**]  
  *dst = src ^ dst*

* `dig` dst[**R**] num[**C**/**R**/**I**]  
  Get digit *num*ber from *dest*inatination and write to dst.  
  *dst = dst / 10^num % 10*
* `dis` dst[**R**] num[**C**/**R**/**I**] val[**C**/**R**/**I**]  
  Set digit to *val*ue at *num*ber in *dest*inatination.  
  *dst = dst + (val % 10 - dst / 10^num % 10) * 10^num*


### Trigonometry

* `cos` dst[**R**] src[**C**/**R**/**I**]  
  *dst = cos(src)*
* `sin` dst[**R**] src[**C**/**R**/**I**]  
  *dst = sin(src)*
* `tan` dst[**R**] src[**C**/**R**/**I**]  
  *dst = tan(src)*
* `atan2` dst[**R**] y[**C**/**R**/**I**] x[**C**/**R**/**I**]  
  *dst = atan2(y, x)*
* `sqrt` dst[**R**] src[**C**/**R**/**I**]  
  *dst = sqrt(src)*
* `exp` dst[**R**] src[**C**/**R**/**I**]  
  *dst = exp(src)*
* `ln` dst[**R**] src[**C**/**R**/**I**]  
  *dst = ln(src)*


### Bitwise

* `band` dst[**R**] src[**C**/**R**/**I**]  
  AND.  
  *dst = dst & src*

* `bor` dst[**R**] src[**C**/**R**/**I**]  
  OR.  
  *dst = dst | src*

* `bxor` dst[**R**] src[**C**/**R**/**I**]  
  XOR.  
  *dst = dst ^ src*

* `bnot` dst[**R**]  
  NOT.  
  *dst = ~dst*

* `bsl` dst[**R**] src[**C**/**R**/**I**]  
  Shift left.  
  *dst = dst << src*

* `bsr` dst[**R**] src[**C**/**R**/**I**]  
  Shift right.  
  *dst = dst >> src*

* `brl` dst[**R**] src[**C**/**R**/**I**]  
  Rotate left.  
  *dst = dst rot<< src*

* `brr` dst[**R**] src[**C**/**R**/**I**]  
  Rotate right.  
  *dst = dst rot>> src*


### Testing operands values

* `teq` a[**C**/**R**/**I**] b[**C**/**R**/**I**]  
  Equal.  
  *a == b*

* `tne` a[**C**/**R**/**I**] b[**C**/**R**/**I**]  
  Not equal.  
  *a != b*

* `tgt` a[**C**/**R**/**I**] b[**C**/**R**/**I**]  
  Greater than.  
  *a > b*

* `tlt` a[**C**/**R**/**I**] b[**C**/**R**/**I**]  
  Less than.  
  *a < b*

* `tge` a[**C**/**R**/**I**] b[**C**/**R**/**I**]  
  Greater or equal than.  
  *a >= b*

* `tle` a[**C**/**R**/**I**] b[**C**/**R**/**I**]  
  Less or equal than.  
  *a <= b*


### Testing operands types

* `tas` a[**T**/**R**/**I**] b[**T**/**R**/**I**]  
  Types are same.  

* `tad` a[**T**/**R**/**I**] b[**T**/**R**/**I**]  
  Types are different.  


### Flow control

* `jmp` addr[**C**/**A**/**L**]  
  Jump to address or label.

* `hlt`  
  *Halt* program execution until it will be resumed by player or by *Run* signal from any **i**nput wire.

* `slp` cnt[**C**]  
  Sleep for specified ticks count.

* `bkr` cnt[**C**]  
  `bkg` cnt[**C**]  
  Block until there are at least *cnt* *r*ed/*g*reen signals.



# TODOs
* examples, demos and docs
* output multiple signals
* program library
* profiling & optimization


# Support fCPU
[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/lato-orange.png)](https://www.buymeacoffee.com/konstg)

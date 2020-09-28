# fCPU

## Specs

* supports blueprints
* supports copy & paste
* supports multiplayer
* supports [Informatron](https://mods.factorio.com/mod/informatron) and [Booktorio](https://mods.factorio.com/mod/Booktorio) in-game wiki
* 64 instructions for whole program
* 8 general purpose registers
* 4 memory slots for vector processing
* 50+ opcodes
* rich math instructions
* SIMD instructions
* two input wires (Red, Green)
* two output wires (Red, Green) have same output signals and values
* parallel output, allows output multiple signals simultaneously (up to 256 signals)
* could be controlled through special input signals
* one tick = one instruction (except for SIMD ones)
* made for geeks



## Description
fCPU is a combinator that includes:

- program text
- a set of registers (for storing signals and numbers)
- processor (command processor and vector coprocessor)


### Program
Programs for fCPU are entered in plain text in simplified [assembly language][1] and consists of lines.
Each line represents one instruction.
An instruction consists of mnemonics and operands.
For example: `mov out1 123[item=copper-ore]`, here `mov` is a mnemonic,` out1` is the first operand, `123[item=copper-ore]` is the second operand.
This instruction tells the processor to send signal `[item=copper-ore]` with number `123` on to wires connected to the output.

Mnemonics are abbreviated names of operations that the processor understands and knows how to execute.
Operands are arguments to operations. They are used to indicate the values ​​on which an operation will be performed.

The following can be used as operands:

- **Signal**: each signal consists of a type and a value (`123[item=copper-ore]`)
  `123` - signal value represented by number
  `[item=copper-ore]` - type can be represented by pictogram or text
- **Register**: this is a special cell that store the transmitted signal indefinitely (`reg1`, `r2`, ...)
- **Memory** slot: one memory slot consists of multiple cells (array) that store the signal indefinitely (`mem1`, `m2`, ...)
- **Input** wire: you can receive signals on wires connected to a combinator's input (`red`,` green`, `red1`, `green@3`, ...)
- **Output** wire: sets the values ​​at the output of a combinator (`out1`, `out2`, ..., `out256`)
- **Address**: instruction address (line number `34`)
- **Label** in the code: written in text with a colon in front (`:label`, `:anyname`, ...)

The processor executes instructions from a written program in turn, line by line.

[1]: This guide is enough for a quick study


### Registers

There are 8 generic purpose read/write registers, named **reg1**, ... **reg8** or alias **r1**, ... **r8**.  
Each register store signal type and numeric value (floating point numbers are supported).  
For example `mov reg2 10[item=iron-plate]`, this instruction assigns to **reg2** value of *10* and type of *[item=iron-plate]*.  

Besides general purpose registers there are some read only registers:  

- **ipt**: current instruction line numer  
- **clk**: clock, value increases every tick  
- **cnr**, **cng**: signals number on red `cnr` or green `cng` input wire  

Output registers (write only):

- **out1**, ..., **out256**: output registers (only integer values)


### Memory

For processing several signals at the same time, the fCPU provides a vector coprocessor that handles SIMD instructions.  
Unlike scalar operations, which process a limited number of signals at a time, vector operations can process hundreds of signals in the same amount of time.  
fCPU Memory is an analogue of registers but for vector instructions.  

There are 4 memory slots available for use.  
Each slot consists of multiple memory cells.  
Each cell stores a signal type and a numeric value.  
Memory slots are addressed: `mem1`, ...,` mem4`.  
To access one cell: `mem2[44]` or `mem1@3` (see Arrays)  


## Arrays\indirect addressing
Each register or memory slot could be adressed not only by direct name:
* **regN** (**reg1**, **r2**, etc... `N` is a register index)
* **memS[M]** (**mem1[32]**, **m4[97]**, etc.. `S` is a memory slot number, `M` is a memory cell index)
But also with indirect pointer:
* **reg@R** (**reg@3**, **r@7**, etc... `R` is a register index)
* **memS@R** (**mem1@3**, **mem4@8**, etc... `R` is a register index)

This allow you to use them as **array** indices.  

For example:
```
mov r1 10[item=iron-plate]
mov r2 20[item=copper-plate]
mov r3 300[item=steel-plate]

mov r5 2
mov r6 r@5 # r6 will be equal to r2, which is 20[item=copper-plate]
mov r4 m1@5 # r4 will be equal to mem1[2]

mov r5 3
mov r7 r@5 # r7 will be equal to r3, which is 300[item=steel-plate]
mov r4 m2@5 # r4 will be equal to mem2[3]

mov r5 5
mov r8 r@5 # r8 will be equal to r5, which is 5
mov r4 m3@5 # r4 will be equal to mem3[5]
```

This approach is also could be used with `red`, `green` input wires and memory slots, for example: `red@1`, `green@8`, `mem1@3`.  



## Control signals
You could control fCPU state by wires (not only manually through game GUI.  
There are some signals for it:

* `[virtual-signal=signal-fcpu-halt]`: Halt program execution.
* `[virtual-signal=signal-fcpu-run]`: Continue running program.
* `[virtual-signal=signal-fcpu-step]`: Execute current instruction.
* `[virtual-signal=signal-fcpu-sleep]`: Sleep specified game ticks.
* `[virtual-signal=signal-fcpu-jump]`: Jump to specified line in program.

If fCPU encounter error in program it will emit `[virtual-signal=signal-fcpu-error]` with line number as value.  


## Mnemonics

Instructions which can be executed one by one on per frame basis.  
Each instruction take one or more operands and modify them or state of fCPU.  

**Legend**

- **S**, signal: consists of **V**alue and **T**ype (`123[item=copper-ore]`)
  - **V**, value: signal value, same as **C**
  - **T**, type: signal type

* **C**, value: integer constant [-2^31..2^31), same as **V** (`-3500`)
* **R**, register: (`reg1`, `r3`, ..., `reg8` or `r@4` notation, or one memory cell `m1[23]`)
* **M**, memory: (`mem1`, `m2`, ..., `mem4`)
* **I**, wire: input wire (`red`, `green`)
* **O**, wire: output buffer (`out1`, `out2`, ..., `out256`)

- **A**, address: instruction address (`5`)
- **L**, label: instruction label (`:labelname`)

`...` - one or more, could be specified multiple times with space separator.  
`?` - optional, may be specified.  

### Common

* `nop`  
  No operation.

* `clr`  
  Clear all registers and output.

* `clr` out  
  Clear all output values.

* `clr` dst...[**R**/**M**/**O**]  
  Clear specified registers or output wires.

* `mov` dst...[**R**/**O**] src[**V**/**T**/**S**/**R**/**I**]  
  Copy signal from source to destination.  
  *dst... = src*

* `emit` src[**V**/**T**/**S**/**R**/**I**]  
  Copy signal from source to output.  
  Same as `mov out1 src`.  

* `ssv` dst...[**R**/**O**] val[**V**/**S**/**R**/**I**]  
  Set signal value.  
  *dst... = val*

* `sst` dst...[**R**/**O**] type[**T**/**S**/**R**/**I**]  
  Set signal type.  
  *dst... = type*

* `fir` dst[**R**/**O**] type[**T**/**R**/**I**]  
  `fig` dst[**R**/**O**] type[**T**/**R**/**I**]  
  Find type in red/green input wire.

* `fim` mem[**M**] dst[**R**/**O**] type[**T**/**R**/**I**]  
  Find type in memory slot.


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

* `rnd` dst[**R**] min[**C**/**R**/**I**] max[**C**/**R**/**I**]  
  Assigns into *dst* a pseudo-random value in range [*min* to *max*] (inclusive).  

* `fract` reg[**R**]  
  Get the fraction part of a real number in register.  
* `floor` reg[**R**]  
  Get the greatest integer less than or equal to real number in register.  
* `round` reg[**R**]  
  Get the closest integer to real number in register.  
* `ceil` reg[**R**]  
  Get the lowest integer greater than or equal to real number in register.  

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


### Flow control

* `jmp` addr[**C**/**A**/**L**/**R**]  
  Jump to address or label.

* `hlt`  
  *Halt* program execution until it will be resumed by player or by *Run* signal from any **i**nput wire.

* `slp` cnt[**C**/**R**]  
  Sleep for specified ticks count.

* `bkr` cnt[**C**/**R**]  
  `bkg` cnt[**C**/**R**]  
  Block until there are at least *cnt* *r*ed/*g*reen signals.

* `btr` type[**T**]
  `btg` type[**T**]
  Block until signal type found in *r*ed/*g*reen input wires.


### Testing operands values

If test succeeded, then the following instruction will be executed.  
You may add `jmp :label` to implement branching. For Example:
```
clr
:counter
inc r1
tlt r1 10
jmp :counter
; r1 now equal to 10
```

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


### Branching

This is the same as testing and then immediately jump if test succeeded.  
The mnemonics same as in testing cases, but with `b` instead of `t` and uses extra operand for jump address.  

```
clr
:counter
inc r1
blt r1 10 :counter
; r1 now equal to 10
```

* `beq` a[**C**/**R**/**I**] b[**C**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Equal.  
  *a == b*
* `bne` a[**C**/**R**/**I**] b[**C**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Not equal.  
  *a != b*

* `bgt` a[**C**/**R**/**I**] b[**C**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Greater than.  
  *a > b*

* `blt` a[**C**/**R**/**I**] b[**C**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Less than.  
  *a < b*

* `bge` a[**C**/**R**/**I**] b[**C**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Greater or equal than.  
  *a >= b*

* `ble` a[**C**/**R**/**I**] b[**C**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Less or equal than.  
  *a <= b*

* `bas` a[**T**/**R**/**I**] b[**T**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Branch if types are same.  

* `bad` a[**T**/**R**/**I**] b[**T**/**R**/**I**] addr[**C**/**A**/**L**/**R**]  
  Branch if types are different.  


## SIMD instructions
Until now you can control fCPU with one instructon per game cycle and operate with a couple signals per instruction.  
But it is not a limit. fCPU supports _Single Instruction Multiple Data_ mnemonics, which means that you could do much more efficient work per instruction and so per one game tick.  
SIMD instructions process several signals in parallel at once, unlike scalar instructions.  

When working with SIMD instructions, the following features should be considered:  
- SIMD instructions do not costs additional time for handling, so UPS friendly
- Some vector instructions are executed for more than 1 tick (`xmov mem1 red` takes 3 ticks for populating `mem1` slot with data from `red` wire)
- Retrieving effective data from affected memory is possible only after completion of a vector instruction


### SIMD Mnemonics
* `xmov` a[**M**/**O**] b[**M**/**I**]
* `xadd` a[**M**/**O**] b[**C**/**R**/**I**]
* `xsub` a[**M**/**O**] b[**C**/**R**/**I**]
* `xmul` a[**M**/**O**] b[**C**/**R**/**I**]
* `xdiv` a[**M**/**O**] b[**C**/**R**/**I**]
* `xmod` a[**M**/**O**] b[**C**/**R**/**I**]
* `xpow` a[**M**/**O**] b[**C**/**R**/**I**]
* `xinc` dst[**O**]
* `xdec` dst[**O**]

* `xand` a[**M**/**O**] b[**C**/**R**/**I**]
* `xor`  a[**M**/**O**] b[**C**/**R**/**I**]
* `xxor` a[**M**/**O**] b[**C**/**R**/**I**]
* `xsl`  a[**M**/**O**] b[**C**/**R**/**I**]
* `xsr`  a[**M**/**O**] b[**C**/**R**/**I**]

* `xmin` dst[**R**/**O**] src[**M**/**I**]
  Searches minimum signal in `src` and copy it to `dst`.
* `xmax` dst[**R**/**O**] src[**M**/**I**]
  Searches maximum signal in `src` and copy it to `dst`.
* `xavg` dst[**R**/**O**] src[**M**/**I**]
  Compute average value in `src` and assign `src` to it.


[comment]: <> (md2frt-skip-section-begin)

# Examples
See: https://mods.factorio.com/mod/fcpu/faq and [Discord channel](https://discord.gg/pCTz9hW)


# Community
* [Discord](https://discord.com/invite/vPnDPhV) for general discussion
* [Factorio Mod portal](https://mods.factorio.com/mod/fcpu/discussion) for bug reports
* [Factorio Forum](https://forums.factorio.com/viewtopic.php?f=190&t=88141) for technical details and mod integration
* [Reddit](https://www.reddit.com/r/factorio/comments/i8e7dh/new_mod_fcpu/)


# TODOs
See [here](https://www.buymeacoffee.com/p/100444)


# Dear supporters
* Lukáš Venhoda (v0.2.0 update)
* Someone (v0.2.12 update)
* kKdH (v0.3.0 update)


# Support fCPU
[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/lato-orange.png)](https://www.buymeacoffee.com/konstg)

[comment]: <> (md2frt-skip-section-end)

# fCPU

## Specs

* supports blueprints
* supports copy & paste
* supports multiplayer
* supports [Informatron](https://mods.factorio.com/mod/informatron) and [Booktorio](https://mods.factorio.com/mod/Booktorio) in-game wiki
* in-game debugger with breakpoints
* 128 instructions for whole program
* 8 general purpose registers
* 4 memory channels for vector processing
* integrated access to the logistic network
* 50+ opcodes
* rich math instructions, trigonometry, rounding
* SIMD instructions, `min`, `max`, filter, comparison, etc...
* two input wires (Red, Green)
* two output wires (Red, Green) have same output signals and values
* parallel output, allows output multiple signals simultaneously
* could be controlled through special input signals (interruptions)
* one tick = one instruction (except for SIMD ones)
* made for geeks



## Description
fCPU is a combinator that includes:

- program text
- a set of registers (for storing signals or\and numbers)
- couple of memory channels (for storing not zero signals and numbers)
- processor (command processor and vector coprocessor)


### Program
Programs for fCPU are entered in plain text in simplified assembly language (this guide is enough for a quick study) and consists of lines.
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
- **Memory** channel: one memory channel consists of multiple cells (array) that store the signal indefinitely (`mem1`, `m2`, ...)
- **LogNet** channel: receives content of a logistic network this fCPU is placed in (`lgn[1]`, `lgn@2`, `logi[34]`, ...)
- **Input** wire: you can receive signals on wires connected to a combinator's input (`red`,` green`, `red1`, `green@3`, ...)
- **Output** wire: sets the values ​​at the output of a combinator (`out1`, `out2`, ..., `out256`)
- **Address**: instruction address (line number `34`)
- **Label** in the code: written in text with a colon in front (`:label`, `:anyname`, ...)

The processor executes instructions from a written program in turn, line by line.


### Registers

There are 8 generic purpose read/write registers, named **reg1**, ... **reg8** or alias **r1**, ... **r8**.  
Each register store signal type and numeric value (floating point numbers are supported).  
For example `mov reg2 10[item=iron-plate]`, this instruction assigns to **reg2** value of *10* and type of *[item=iron-plate]*.  

Besides general purpose registers there are some read only registers:  

- **ipt**: current instruction line numer  
- **clk**: clock, value increases every tick  
- **cnr**, **cng**: signals number on red `cnr` or green `cng` input wire  
- **cnl**: count of a various items in `lognet`, not a sum of its values  
- **cnm1**, ..., **cnm4**: signals number in memory  

Output registers (write only):

- **out1**, ..., **out256**: output registers (only integer values)


### Memory

For processing several signals at the same time, the fCPU provides a vector coprocessor that handles SIMD instructions.  
Unlike scalar operations, which process a limited number of signals at a time, vector operations can process hundreds of signals in the same amount of time.  
fCPU Memory is an analogue of registers but for vector instructions.  

There are 4 memory channels available for use.  
Each channel consists of multiple memory cells.  
Each cell stores a signal type and a numeric value.  
Memory channels are addressed: `mem1`, ...,` mem4`.  
To access one cell: `mem2[44]` or `mem1@3` (see Arrays)  


### Logistic network (LogNet)

Acts as a single memory channel, except that it is read-only and other obvious limitations.  
`lgn` channel could be `xmov`'ed into memory channel for manipulations.  


## Arrays\indirect addressing
Each register, memory channel or logistic network item could be addressed not only by direct name:
* **regN** (**reg1**, **r2**, etc... `N` is a register index)
* **memC[M]** (**mem1[32]**, **m4[97]**, etc.. `C` is a memory channel number, `M` is a memory cell index)
* **lgn[I]** (**lgn[43]**, **logi[12]**, etc... `I` is a logistic network item index)
But also with indirect pointer:
* **reg@R** (**reg@3**, **r@7**, etc... `R` is a register index)
* **memC@R** (**mem1@3**, **mem4@8**, etc... `R` is a register index)
* **lgn@R** (**lgn@2**, **logi@8**, etc... `R` is a register index)

This allow you to use values in registers as **array** indices.  

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

This approach is also could be used with `red`, `green` input wires and memory channels, for example: `red@1`, `green@8`, `mem1@3`.  



## Control signals, interruptions
You could control fCPU state by wires, not only manually through game GUI.  
There are some signals for it:
* `[virtual-signal=signal-fcpu-halt]`: Halt program execution.
* `[virtual-signal=signal-fcpu-run]`: Continue running program.
* `[virtual-signal=signal-fcpu-step]`: Execute current instruction and move to next.
* `[virtual-signal=signal-fcpu-sleep]`: Sleep specified game ticks. In sleep mode fCPU do not handle interruptions.
* `[virtual-signal=signal-fcpu-jump]`: Jump to specified line in program.

If fCPU encounter error in program it will output `[virtual-signal=signal-fcpu-error]` with line number as value.  


## Mnemonics

Instructions which can be executed one by one on per frame basis.  
Each instruction take one or more operands and modify them or state of fCPU.  

**Legend**

* **V**, value: integer constant in range [-2^31..2^31), (`-3500`)
* **T**, type: signal type (`[item=iron-ore]`)
* **VT**, signal: consists of **V**alue and **T**ype (`123[item=copper-ore]`)
* **R**, register: (`reg1`, `r3`, ..., `reg8` or `r@4` notation, or one memory cell `m1[23]` or one input wire signal `red34`, `green@3`)
* **M**, memory: channel (`mem1`, `m2`, ..., `mem4`)
* **N**, lognet: channel (`lgn`, `logi`, `lnc`)
* **I**, wire: input wire (`red`, `green`)
* **O**, wire: output buffer (`out1`, `out2`, ..., `out256`, `out`)

- **A**, address: instruction address (`5`)
- **L**, label: instruction label (`:labelname`)
- **S**, string: used in utility mnemonics (`'rotation_speed'`)

`...` - one or more, could be specified multiple times with space separator.  
`?` - optional, may be specified.  

### Common

* `nop`  
  No operation.

* `clr`  
  Clear all registers, memory channels and output.

* `clr` reg  
  Clear all registers.

* `clr` out  
  Clear all output values.

* `clr` mem  
  Clear all memory channels.

* `clr` dst...[**R**/**M**/**O**]  
  Clear specified registers, memory channels or output wires (`mem3`, `r2`, `out4`).

* `mov` dst...[**R**/**O**] src[**V**/**T**/**VT**/**R**]  
  Copy signal from source to destination.  
  *dst... = src*

* `ssv` dst...[**R**/**O**] val[**V**/**R**]  
  Set signal value.  
  *dst... = val*

* `sst` dst...[**R**/**O**] type[**T**/**R**]  
  Set signal type.  
  *dst... = type*

* `fid` dst[**R**/**O**] src[**I**/**M**] type[**T**/**R**]  
  Find *type* in *src* (memory or red/green input wire), then assign *dst* to signal type and number value.

* `idx` dst[**R**] src[**I**/**M**] type[**T**/**R**]  
  Find *type* in *src* (memory or red/green input wire), then assing *dst* to the index of memory cell or input wire location.


* `fir` dst[**R**/**O**] type[**T**/**R**]  
  `fig` dst[**R**/**O**] type[**T**/**R**]  
  Shorthands for `fid ... red ...` and `fid ... green ...`.  


### Swap

* `swp` reg1[**R**] reg2[**R**]  
  Swap signals in memory cells.
* `swpt` reg1[**R**] reg2[**R**]  
  Swap signal types in memory cells.
* `swpv` reg1[**R**] reg2[**R**]  
  Swap signal values in memory cells.


### Arithmetic

* `add` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  *dst = src + val* (if src is specified)  
  *dst = dst + val*  
* `sub` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  *dst = src - val* (if src is specified)  
  *dst = dst - val*  
* `mul` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  *dst = src \* val* (if src is specified)  
  *dst = dst \* val*  
* `div` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  *dst = src / val* (if src is specified)  
  *dst = dst / val*  
* `mod` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  *dst = src % val* (if src is specified)  
  *dst = dst % val*  
* `pow` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  *dst = src ^ val* (if src is specified)  
  *dst = dst ^ val*  

* `inc` dst[**R**]  
  *dst = dst + 1*
* `dec` dst[**R**]  
  *dst = dst - 1*

* `subi` dst[**R**] val[**V**/**R**]  
  *dst = val - dst*
* `divi` dst[**R**] val[**V**/**R**]  
  *dst = val / dst*
* `modi` dst[**R**] val[**V**/**R**]  
  *dst = val % dst*
* `powi` dst[**R**] val[**V**/**R**]  
  *dst = val ^ dst*

* `rnd` dst[**R**] min[**V**/**R**] max[**V**/**R**]  
  Assigns into *dst* a pseudo-random value in range [*min* to *max*] (inclusive).  

* `fract` reg[**R**]  
  Get the fraction part of a real number in register.  
* `floor` reg[**R**]  
  Get the greatest integer less than or equal to real number in register.  
* `round` reg[**R**]  
  Get the closest integer to real number in register.  
* `ceil` reg[**R**]  
  Get the lowest integer greater than or equal to real number in register.  

* `dig` dst[**R**] num[**V**/**R**]  
  Get digit *num*ber from *dest*inatination and write to dst.  
  *dst = dst / 10^num % 10*
* `dis` dst[**R**] num[**V**/**R**] val[**V**/**R**]  
  Set digit to *val*ue at *num*ber in *dest*inatination.  
  *dst = dst + (val % 10 - dst / 10^num % 10) * 10^num*


### Trigonometry

* `cos` dst[**R**] src[**V**/**R**]  
  *dst = cos(src)*
* `sin` dst[**R**] src[**V**/**R**]  
  *dst = sin(src)*
* `tan` dst[**R**] src[**V**/**R**]  
  *dst = tan(src)*
* `atan2` dst[**R**] y[**V**/**R**] x[**V**/**R**]  
  *dst = atan2(y, x)*
* `sqrt` dst[**R**] src[**V**/**R**]  
  *dst = sqrt(src)*
* `exp` dst[**R**] src[**V**/**R**]  
  *dst = exp(src)*
* `ln` dst[**R**] src[**V**/**R**]  
  *dst = ln(src)*


### Bitwise

* `band` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  AND.  
  *dst = src & val* (if src is specified)
  *dst = dst & val*

* `bor` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  OR.  
  *dst = src | val* (if src is specified)
  *dst = dst | val*

* `bxor` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  XOR.  
  *dst = src ^ val* (if src is specified)
  *dst = dst ^ val*

* `bnot` dst[**R**] src?[**R**]  
  NOT.  
  *dst = ~src* (if src is specified)
  *dst = ~dst*

* `bsl` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  Shift left.  
  *dst = src << val* (if src is specified)
  *dst = dst << val*

* `bsr` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  Shift right.  
  *dst = src >> val* (if src is specified)
  *dst = dst >> val*

* `brl` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  Rotate left.  
  *dst = src rot<< val* (if src is specified)
  *dst = dst rot<< val*

* `brr` dst[**R**] src?[**V**/**R**] val[**V**/**R**]  
  Rotate right.  
  *dst = src rot>> val* (if src is specified)
  *dst = dst rot>> val*


### Flow control

* `lea` dst[**R**/**O**] addr[**L**]  
  Load label *addr*ess into *dst*.

* `jmp` addr[**V**/**A**/**L**/**R**]  
  Jump to address or label.

* `jmp` addr[**V**/**A**/**L**/**R**] offset[**V**/**R**]  
  Jump to address + offset or label + offset.  
  For example: `jmp ipt -2`, jump at two lines before current instruction (`ipt`).

* `hlt`  
  *Halt* program execution until it will be resumed by player or by *Run* signal from any **i**nput wire.

* `slp` cnt[**V**/**R**]  
  Sleep for specified ticks count.  
  fCPU do not handle interruptions while sleeping.  

#### Block execution until condition met
Instructions execute the next line immediately after them (in the same tick) as soon as the condition is met.  
This allows them to be used to copy the input signal that triggered continuation.  
For example:  
```
mov r1 0[virtual-signal=signal-green]
btrc r1
xmov m1 red
```

* `bkr` cnt[**V**/**R**]  
  `bkg` cnt[**V**/**R**]  
  `bkl` cnt[**V**/**R**]  
  Block until there are at least *cnt* signals on *r*ed/*g*reen wires or *l*ognet.

* `btr` type[**T**/**R**]  
  `btg` type[**T**/**R**]  
  `bti` type[**T**/**R**]  
  `btl` type[**T**/**R**]  
  Block until signal type found on *r*ed/*g*reen/both_*i*nput wires or *l*ognet.

* `btrc` reg[**R**]  
  `btgc` reg[**R**]  
  `btic` reg[**R**]  
  `btlc` reg[**R**]  
  Block while reference *reg*ister have same type-value as in *r*ed/*g*reen/both_*i*nput wires or *l*ognet.  
  After red/green/input or *l*ognet value were changed, assign new value to *register* and continue execution.


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

* `teq` a[**V**/**S**/**R**] b[**V**/**S**/**R**]  
  Equal.  
  *a == b*

* `tne` a[**V**/**S**/**R**] b[**V**/**S**/**R**]  
  Not equal.  
  *a != b*

* `tgt` a[**V**/**S**/**R**] b[**V**/**S**/**R**]  
  Greater than.  
  *a > b*

* `tlt` a[**V**/**S**/**R**] b[**V**/**S**/**R**]  
  Less than.  
  *a < b*

* `tge` a[**V**/**S**/**R**] b[**V**/**S**/**R**]  
  Greater or equal than.  
  *a >= b*

* `tle` a[**V**/**S**/**R**] b[**V**/**S**/**R**]  
  Less or equal than.  
  *a <= b*


### Testing operands types

* `tas` a[**T**/**R**] b[**T**/**R**]  
  Types are same.  

* `tad` a[**T**/**R**] b[**T**/**R**]  
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

* `beq` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Equal.  
  If *a == b* then `jmp addr offset`

* `bne` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Not equal.  
  If *a != b* then `jmp addr offset`

* `bgt` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Greater than.  
  If *a > b* then `jmp addr offset`

* `blt` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Less than.  
  If *a < b* then `jmp addr offset`

* `bge` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Greater or equal than.  
  If *a >= b* then `jmp addr offset`

* `ble` a[**V**/**S**/**R**] b[**V**/**S**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Less or equal than.  
  If *a <= b* then `jmp addr offset`

* `bas` a[**T**/**R**] b[**T**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Branch if types are same.  

* `bad` a[**T**/**R**] b[**T**/**R**] addr[**V**/**A**/**L**/**R**] offset?[**V**/**R**]  
  Branch if types are different.  


### Utility mnemonics
* `ugpf` dst[**R**] name[**T**/**R**] field[**S**]
  *Utility Get Prototype Field*  
  Find prototype with *name* and assign *dst* to *field* value (only numbers supported).  
  This instruction sequentially checks fields in:
    1. https://lua-api.factorio.com/latest/LuaItemPrototype.html
    2. https://lua-api.factorio.com/latest/LuaEntityPrototype.html
  For example:  
  - `ugpf r1 [item=inserter] 'inserter_rotation_speed'`
  - `ugpf r2 [item=copper-ore] 'stack_size'` (this is a same as `uiss r1 [item=copper-ore]`)
  - `ugpf r3 [item=logistic-chest-buffer] 'get_inventory_size(defines.inventory.item_main)'`

  You may use dot `.` for diving inside this prototypes.  
  To check if the item is a science pack use this example:  
  - `ugpf r1 [item=automation-science-pack] 'subgroup.name'`
    `beq r1 'science-pack' :yeah_science_btch`


* `uiss` dst[**R**] type[**T**/**R**]  
  **DEPRECATED: please use `ugpf dst type 'stack_size'`**  
  *Utility Item Stack Size*  
  Assign stack size to *dst* for specified item *type*.  



## SIMD instructions
Until now you can control fCPU with one instructon per game cycle and operate with a couple signals per instruction.  
But it is not a limit. fCPU supports _Single Instruction Multiple Data_ mnemonics, which means that you could do much more efficient work per instruction and so per one game tick.  
SIMD instructions process several signals in parallel at once, unlike scalar instructions.  

When working with SIMD instructions, the following features should be considered:  
- SIMD instructions do not costs additional time for handling, so UPS friendly
- Some vector instructions are executed for more than 1 tick (`xmov mem1 red` takes 3 ticks for populating `mem1` channel with data from `red` wire)
- Retrieving effective data from affected memory is possible only after completion of a vector instruction

**Pseudocode legend**
- `dst()`, `src()`, etc: unordered memory (set)
- `dst[]`, `src[]`, etc: ordered memory (array) *NOT IMPLEMENTED YET*


### SIMD Common

* `xmov` dst[**M**/**O**] src[**I**/**M**/**N**]
  *dst(each) = src(each)*

* `emit` dst[**M**] val...[**V**/**T**/**VT**/**R**]
  Append *val*ues to *dst* memory (with random ordering until v0.5.0).  

* `xuni` dst[**M**/**O**] a[**I**/**M**/**N**] b[**I**/**M**/**N**]
  Merge two memory channels into unite one.  
  *dst(each) = a(each) + b(each)*

* `xflt` dst[**M**/**O**] src?[**I**/**M**/**N**] mask[**I**/**M**/**N**]
  Copy all the signals from *src* to *dst* having *mask* as whitelist.
  *Internal design by https://www.reddit.com/user/Halke1986/*

* `xadd` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  *dst(each) = dst + val* 
  *dst(each) = src + val* (if src specified)

* `xsub` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  *dst(each) = dst - val*
  *dst(each) = src - val* (if src specified)

* `xmul` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  *dst(each) = dst \* val*
  *dst(each) = src \* val* (if src specified)

* `xdiv` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  *dst(each) = dst / val*
  *dst(each) = src / val* (if src specified)

* `xmod` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  *dst(each) = dst % val*
  *dst(each) = src % val* (if src specified)

* `xpow` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  *dst(each) = dst ^ val*
  *dst(each) = src ^ val* (if src specified)


### SIMD Comparision

Compares each signal value in memory with operand specified and pass it to destination if condition met.  
In two operand version *src* is the same as a *dst*.  

* `xceq` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]  
  Equal.  
  *dst(each) = src(each), if src(each) == val*

* `xcne` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]  
  Not equal.  
  *dst(each) = src(each), if src(each) != val*

* `xcgt` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]  
  Greater than.  
  *dst(each) = src(each), if src(each) > val*

* `xclt` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]  
  Less than.  
  *dst(each) = src(each), if src(each) < val*

* `xcge` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]  
  Greater or equal than.  
  *dst(each) = src(each), if src(each) >= val*

* `xcle` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]  
  Less or equal than.  
  *dst(each) = src(each), if src(each) <= val*


### SIMD Bitwise

* `xand` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  AND.  
  *dst(each) = dst & val* 
  *dst(each) = src & val* (if src specified)

* `xor`  dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  OR.  
  *dst(each) = dst | val* 
  *dst(each) = src | val* (if src specified)

* `xxor` dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  XOR.  
  *dst(each) = dst ^ val* 
  *dst(each) = src ^ val* (if src specified)

* `xsl`  dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  Shift left.  
  *dst(each) = dst << val* 
  *dst(each) = src << val* (if src specified)

* `xsr`  dst[**M**/**O**] src?[**I**/**M**/**N**] val[**V**/**R**]
  Shift right.  
  *dst(each) = dst >> val* 
  *dst(each) = src >> val* (if src specified)


### SIMD Statistics

* `xmin` dst[**R**/**O**] src[**I**/**M**/**N**]
  Searches minimum signal in `src` and copy it to `dst`.
* `xmax` dst[**R**/**O**] src[**I**/**M**/**N**]
  Searches maximum signal in `src` and copy it to `dst`.
* `xavg` dst[**R**/**O**] src[**I**/**M**/**N**]
  Compute average value in `src` and assign `dst` to it.

* `xmini` dst[**R**/**O**] src[**I**/**M**/**N**]
  Searches minimum signal in `src` and assing its index into `dst`.
* `xmaxi` dst[**R**/**O**] src[**I**/**M**/**N**]
  Searches maximum signal in `src` and assing its index into `dst`.


## SIMD Memory (Explanation)
I'll try to explain how the mod works with memory and why it's done this way.  

Each Factorio wire can contain a huge number of signals simultaneously (hundreds). These signals are not sorted in any way and in fact have a random indices. To make everything look more beautiful, GUI panels sort signals in descending order (power poles and ⓘ tooltips).  

To process a large number of signals in the game, vanilla combinators optimized inside the game itself in C++. If you try to process a similar number of signals in the LUA mod, there will be significant overhead and performance degradation. This applies to any Factorio mod.  

To get around this, fCPU uses a trick - it partially compiles the written program (SIMD mnemonics `x*`) into invisible circuits with vanilla combinators and coordinates their execution line-by-line. This part of fCPU called coprocessor. It provides better performance than similar calculations on the LUA.  

Unlike registers, which are implemented as ordinary variables and always retain their indices, the memory for SIMD commands is also implemented using vanilla combinators.  

Here comes the most important thing:  
To modify the memory, you need to subtract old value and add a new one for same signal type.
Like any other vanilla combinator operation, this breaks the signal indices.  


## User Interface

### Hotkeys

* **F5** = Run/Continue
* **Shift** + **F5** = Stop
* **Ctrl** + **Shift** + **F5** = Restart
* **F6** = Pause
* **F7**, **F11** = Step into
* **F8**, **F10** = Step over


[comment]: <> (md2frt-skip-section-begin)

# Examples
See: https://mods.factorio.com/mod/fcpu/faq and [Discord channel](https://discord.gg/pCTz9hW)


# Community
* [Discord](https://discord.com/invite/vPnDPhV) for general discussion
* [Factorio Mod portal](https://mods.factorio.com/mod/fcpu/discussion) for bug reports
* [Factorio Forum](https://forums.factorio.com/viewtopic.php?f=190&t=88141) for technical details and mod integration
* [Reddit](https://www.reddit.com/r/factorio/comments/i8e7dh/new_mod_fcpu/)


# Roadmap & TODOs
See [here](https://www.buymeacoffee.com/p/100444)


# Dear supporters
* masterkrovel (v0.4.14 update)
* Spencer Nelson (v0.4.14 update)
* @Baughnie (v0.4.14 update)
* @orangedude27 (v0.4.14 update)
* msipos2117 (v0.4.10 update)
* Chiko (v0.4.0 update)
* cid0rz (v0.4.0 update)
* Quorzar (v0.4.0 update)
* kKdH (v0.3.0 update)
* Blu2403 (v0.2.12 update)
* Lukáš Venhoda (v0.2.0 update)

**Thanks for supporting fCPU!**


# Support fCPU
[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/lato-orange.png)](https://www.buymeacoffee.com/konstg)

[comment]: <> (md2frt-skip-section-end)

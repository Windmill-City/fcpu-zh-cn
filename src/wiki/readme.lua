return [==[[font=heading-1]
fCPU[/font]
[font=heading-2]
Specs[/font]
[virtual-signal=signal-dot] supports blueprints
[virtual-signal=signal-dot] supports copy & paste
[virtual-signal=signal-dot] supports multiplayer
[virtual-signal=signal-dot] 64 instructions for whole program
[virtual-signal=signal-dot] 8 general purpose registers
[virtual-signal=signal-dot] 50+ opcodes
[virtual-signal=signal-dot] rich math instructions
[virtual-signal=signal-dot] two input wires (Red, Green)
[virtual-signal=signal-dot] two output wires (Red, Green) have same output signals and values
[virtual-signal=signal-dot] parallel output, allows output multiple signals simultaneously (up to 256 signals)
[virtual-signal=signal-dot] could be controlled through special input signals
[virtual-signal=signal-dot] one tick = one instruction
[virtual-signal=signal-dot] made for geeks

[font=heading-2]
Description[/font]
fCPU is a combinator that includes:
[virtual-signal=signal-dot] program text
[virtual-signal=signal-dot] a set of registers (for storing signals and numbers)
[virtual-signal=signal-dot] processor (command processor)

[font=heading-3]
Program[/font]
Programs for fCPU are entered in plain text in simplified [assembly language][a]1[/a] and consists of lines.
Each line represents one instruction.
An instruction consists of mnemonics and operands.
For example: [font=default-mono][color=default]mov out1 123[item=copper-ore][/color][/font], here [font=default-mono][color=default]mov[/color][/font] is a mnemonic,[font=default-mono][color=default] out1[/color][/font] is the first operand, [font=default-mono][color=default]123[item=copper-ore][/color][/font] is the second operand.
This instruction tells the processor to send signal [font=default-mono][color=default][item=copper-ore][/color][/font] with number [font=default-mono][color=default]123[/color][/font] on to wires connected to the output.

Mnemonics are abbreviated names of operations that the processor understands and knows how to execute.
Operands are arguments to operations. They are used to indicate the values ​​on which an operation will be performed.

The following can be used as operands:
[virtual-signal=signal-dot] [font=default-bold]Signal[/font]: each signal consists of a type and a value ([font=default-mono][color=default]123[item=copper-ore][/color][/font])
        [font=default-mono][color=default]123[/color][/font] - signal value represented by number
        [font=default-mono][color=default][item=copper-ore][/color][/font] - type can be represented by pictogram or text
[virtual-signal=signal-dot] [font=default-bold]Register[/font]: these are special cells that store the transmitted signal indefinitely ([font=default-mono][color=default]reg1[/color][/font],[font=default-mono][color=default] r2[/color][/font], ...)
[virtual-signal=signal-dot] [font=default-bold]Input[/font] wire: you can receive signals on wires connected to a combinator's input ([font=default-mono][color=default]red[/color][/font],[font=default-mono][color=default] green[/color][/font])
[virtual-signal=signal-dot] [font=default-bold]Output[/font] wire: sets the values ​​at the output of a combinator ([font=default-mono][color=default]out1[/color][/font],[font=default-mono][color=default] out2[/color][/font], ..., [font=default-mono][color=default]out256[/color][/font])
[virtual-signal=signal-dot] [font=default-bold]Address[/font]: instruction address (line number)
[virtual-signal=signal-dot] [font=default-bold]Label[/font] in the code: written in text with a colon in front ([font=default-mono][color=default]:label[/color][/font], [font=default-mono][color=default]:anyname[/color][/font], ...)

The processor executes instructions from a written program in turn, line by line.
[font=heading-3]
Registers[/font]
There are 8 generic purpose read/write registers, named [font=default-bold]reg1[/font], ... [font=default-bold]reg8[/font] or alias [font=default-bold]r1[/font], ... [font=default-bold]r8[/font].  
Each register store signal type and numeric value (floating point numbers are supported).  
For example [font=default-mono][color=default]mov reg2 10[item=iron-plate][/color][/font], this instruction assigns to [font=default-bold]reg2[/font] value of [font=default-small]10[/font] and type of [font=default-small][a]item=iron-plate[/a][/font].  

Besides general purpose registers there are some read only registers:  
[virtual-signal=signal-dot] [font=default-bold]ipt[/font]: current instruction line numer  
[virtual-signal=signal-dot] [font=default-bold]clk[/font]: clock, value increases every tick  
[virtual-signal=signal-dot] [font=default-bold]cnr[/font], [font=default-bold]cng[/font]: signals number on red [font=default-mono][color=default]cnr[/color][/font] or green [font=default-mono][color=default]cng[/color][/font] input wire  

Output registers (write only):
[virtual-signal=signal-dot] [font=default-bold]out1[/font], ..., [font=default-bold]out256[/font]: output registers (only integer values)

[font=heading-2]
Arrays\indirect addressing[/font]
Each register could be adressed not only by direct name [font=default-bold]regN[/font] ([font=default-bold]reg1[/font], [font=default-bold]r2[/font], etc...) but also with indirect pointer [font=default-bold]reg@N[/font] ([font=default-bold]reg@3[/font], [font=default-bold]r@7[/font], etc...). This allow you to use them as [font=default-bold]array[/font] indices.
For example:
[font=default-mono][color=default]mov r1 10[item=iron-plate]
mov r2 20[item=copper-plate]
mov r3 300[item=steel-plate]

mov r5 2
mov r6 r@5 # r6 will be equal to r2, which is 20[item=copper-plate]

mov r5 3
mov r7 r@5 # r7 will be equal to r3, which is 300[item=steel-plate]

mov r5 5
mov r8 r@5 # r8 will be equal to r5, which is 5
[/color][/font][font=heading-2]
Control signals[/font]
You could control fCPU state by wires (not only manually through game GUI.  
There are some signals for it:
[virtual-signal=signal-dot] [font=default-mono][color=default][virtual-signal=signal-fcpu-halt][/color][/font]: Halt program execution.
[virtual-signal=signal-dot] [font=default-mono][color=default][virtual-signal=signal-fcpu-run][/color][/font]: Continue running program.
[virtual-signal=signal-dot] [font=default-mono][color=default][virtual-signal=signal-fcpu-step][/color][/font]: Execute current instruction.
[virtual-signal=signal-dot] [font=default-mono][color=default][virtual-signal=signal-fcpu-sleep][/color][/font]: Sleep specified game ticks.
[virtual-signal=signal-dot] [font=default-mono][color=default][virtual-signal=signal-fcpu-jump][/color][/font]: Jump to specified line in program.

If fCPU encounter error in program it will emit [font=default-mono][color=default][virtual-signal=signal-fcpu-error][/color][/font] with line number as value.  
[font=heading-2]
Mnemonics[/font]
Instructions which can be executed one by one on per frame basis.  
Each instruction take one or more operands and modify them or state of fCPU.  
[font=heading-3]
Legend[/font]
[virtual-signal=signal-dot] [font=default-bold]S[/font], signal: consists of [font=default-bold]V[/font]alue and [font=default-bold]T[/font]ype ([font=default-mono][color=default]123[item=copper-ore][/color][/font])
        [virtual-signal=signal-dot] [font=default-bold]V[/font], value: signal value, same as [font=default-bold]C[/font]
        [virtual-signal=signal-dot] [font=default-bold]T[/font], type: signal type

[virtual-signal=signal-dot] [font=default-bold]C[/font], value: integer constant [-2^31..2^31), same as [font=default-bold]V[/font] ([font=default-mono][color=default]-3500[/color][/font])
[virtual-signal=signal-dot] [font=default-bold]R[/font], register: ([font=default-mono][color=default]reg1[/color][/font], [font=default-mono][color=default]reg2[/color][/font], ..., [font=default-mono][color=default]reg8[/color][/font])
[virtual-signal=signal-dot] [font=default-bold]I[/font], wire: input wire ([font=default-mono][color=default]red[/color][/font], [font=default-mono][color=default]green[/color][/font])
[virtual-signal=signal-dot] [font=default-bold]O[/font], wire: output wire ([font=default-mono][color=default]out1[/color][/font], [font=default-mono][color=default]out2[/color][/font], ..., [font=default-mono][color=default]out256[/color][/font])

[virtual-signal=signal-dot] [font=default-bold]A[/font], address: instruction address ([font=default-mono][color=default]5[/color][/font])
[virtual-signal=signal-dot] [font=default-bold]L[/font], label: instruction label ([font=default-mono][color=default]:labelname[/color][/font])

[font=default-mono][color=default]...[/color][/font] - one or more, could be specified multiple times with space separator.  
[font=default-mono][color=default]?[/color][/font] - optional, may be specified.  
[font=heading-3]
Common[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]nop[/color][/font]  
        No operation.


[virtual-signal=signal-dot] [font=default-mono][color=default]clr[/color][/font]  
        Clear all registers and output.


[virtual-signal=signal-dot] [font=default-mono][color=default]clr[/color][/font] out  
        Clear all output values.


[virtual-signal=signal-dot] [font=default-mono][color=default]clr[/color][/font] reg...[[font=default-bold]R[/font]/[font=default-bold]O[/font]]  
        Clear specified registers.


[virtual-signal=signal-dot] [font=default-mono][color=default]mov[/color][/font] dst...[[font=default-bold]R[/font]/[font=default-bold]O[/font]] src[[font=default-bold]V[/font]/[font=default-bold]T[/font]/[font=default-bold]S[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Copy signal from source to destination.  
        [font=default-small]dst... = src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]emit[/color][/font] src[[font=default-bold]V[/font]/[font=default-bold]T[/font]/[font=default-bold]S[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Copy signal from source to output.  
        Same as [font=default-mono][color=default]mov out src[/color][/font].  


[virtual-signal=signal-dot] [font=default-mono][color=default]ssv[/color][/font] dst...[[font=default-bold]R[/font]/[font=default-bold]O[/font]] val[[font=default-bold]V[/font]/[font=default-bold]S[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Set signal value.  
        [font=default-small]dst... = val[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]sst[/color][/font] dst...[[font=default-bold]R[/font]/[font=default-bold]O[/font]] type[[font=default-bold]T[/font]/[font=default-bold]S[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Set signal type.  
        [font=default-small]dst... = type[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]fir[/color][/font] dst[[font=default-bold]R[/font]/[font=default-bold]O[/font]] type[[font=default-bold]T[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-mono][color=default]fig[/color][/font] dst[[font=default-bold]R[/font]/[font=default-bold]O[/font]] type[[font=default-bold]T[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Find type in red/green input wire.


[font=heading-3]
Swap[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]swp[/color][/font] reg1[[font=default-bold]R[/font]] reg2[[font=default-bold]R[/font]]  
        Swap signals in memory cells.
[virtual-signal=signal-dot] [font=default-mono][color=default]swpt[/color][/font] reg1[[font=default-bold]R[/font]] reg2[[font=default-bold]R[/font]]  
        Swap signal types in memory cells.
[virtual-signal=signal-dot] [font=default-mono][color=default]swpv[/color][/font] reg1[[font=default-bold]R[/font]] reg2[[font=default-bold]R[/font]]  
        Swap signal values in memory cells.


[font=heading-3]
Arithmetic[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]add[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = dst + src[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]sub[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = dst - src[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]mul[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = dst [/font] src*
[virtual-signal=signal-dot] [font=default-mono][color=default]div[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = dst / src[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]mod[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = dst % src[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]pow[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = dst ^ src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]inc[/color][/font] dst[[font=default-bold]R[/font]]  
        [font=default-small]dst = dst + 1[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]dec[/color][/font] dst[[font=default-bold]R[/font]]  
        [font=default-small]dst = dst - 1[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]subi[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = src - dst[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]divi[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = src / dst[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]modi[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = src % dst[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]powi[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = src ^ dst[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]dig[/color][/font] dst[[font=default-bold]R[/font]] num[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Get digit [font=default-small]num[/font]ber from [font=default-small]dest[/font]inatination and write to dst.  
        [font=default-small]dst = dst / 10^num % 10[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]dis[/color][/font] dst[[font=default-bold]R[/font]] num[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] val[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Set digit to [font=default-small]val[/font]ue at [font=default-small]num[/font]ber in [font=default-small]dest[/font]inatination.  
        [font=default-small]dst = dst + (val % 10 - dst / 10^num % 10) [/font] 10^num*


[font=heading-3]
Trigonometry[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]cos[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = cos(src)[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]sin[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = sin(src)[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]tan[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = tan(src)[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]atan2[/color][/font] dst[[font=default-bold]R[/font]] y[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] x[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = atan2(y, x)[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]sqrt[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = sqrt(src)[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]exp[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = exp(src)[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]ln[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        [font=default-small]dst = ln(src)[/font]


[font=heading-3]
Bitwise[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]band[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        AND.  
        [font=default-small]dst = dst & src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]bor[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        OR.  
        [font=default-small]dst = dst | src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]bxor[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        XOR.  
        [font=default-small]dst = dst ^ src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]bnot[/color][/font] dst[[font=default-bold]R[/font]]  
        NOT.  
        [font=default-small]dst = ~dst[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]bsl[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Shift left.  
        [font=default-small]dst = dst << src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]bsr[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Shift right.  
        [font=default-small]dst = dst >> src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]brl[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Rotate left.  
        [font=default-small]dst = dst rot<< src[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]brr[/color][/font] dst[[font=default-bold]R[/font]] src[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Rotate right.  
        [font=default-small]dst = dst rot>> src[/font]


[font=heading-3]
Testing operands values[/font]
If test succeeded, then next instruction will be executed.
[virtual-signal=signal-dot] [font=default-mono][color=default]teq[/color][/font] a[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Equal.  
        [font=default-small]a == b[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]tne[/color][/font] a[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Not equal.  
        [font=default-small]a != b[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]tgt[/color][/font] a[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Greater than.  
        [font=default-small]a > b[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]tlt[/color][/font] a[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Less than.  
        [font=default-small]a < b[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]tge[/color][/font] a[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Greater or equal than.  
        [font=default-small]a >= b[/font]


[virtual-signal=signal-dot] [font=default-mono][color=default]tle[/color][/font] a[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]C[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Less or equal than.  
        [font=default-small]a <= b[/font]


[font=heading-3]
Testing operands types[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]tas[/color][/font] a[[font=default-bold]T[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]T[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Types are same.  


[virtual-signal=signal-dot] [font=default-mono][color=default]tad[/color][/font] a[[font=default-bold]T[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]] b[[font=default-bold]T[/font]/[font=default-bold]R[/font]/[font=default-bold]I[/font]]  
        Types are different.  


[font=heading-3]
Flow control[/font]
[virtual-signal=signal-dot] [font=default-mono][color=default]jmp[/color][/font] addr[[font=default-bold]C[/font]/[font=default-bold]A[/font]/[font=default-bold]L[/font]/[font=default-bold]R[/font]]  
        Jump to address or label.


[virtual-signal=signal-dot] [font=default-mono][color=default]hlt[/color][/font]  
        [font=default-small]Halt[/font] program execution until it will be resumed by player or by [font=default-small]Run[/font] signal from any [font=default-bold]i[/font]nput wire.


[virtual-signal=signal-dot] [font=default-mono][color=default]slp[/color][/font] cnt[[font=default-bold]C[/font]/[font=default-bold]R[/font]]  
        Sleep for specified ticks count.


[virtual-signal=signal-dot] [font=default-mono][color=default]bkr[/color][/font] cnt[[font=default-bold]C[/font]/[font=default-bold]R[/font]]  
        [font=default-mono][color=default]bkg[/color][/font] cnt[[font=default-bold]C[/font]/[font=default-bold]R[/font]]  
        Block until there are at least [font=default-small]cnt[/font] [font=default-small]r[/font]ed/[font=default-small]g[/font]reen signals.


[font=heading-1]
Examples[/font]
See: https://mods.factorio.com/mod/fcpu/faq
[font=heading-1]
Community[/font]
[virtual-signal=signal-dot] [a]Reddit[/a](https://www.reddit.com/r/factorio/comments/i8e7dh/new[font=default-small]mod[/font]fcpu/) for general discussion
[virtual-signal=signal-dot] [a]Factorio Mod portal[/a] for bug reports
[virtual-signal=signal-dot] [a]Factorio Forum[/a] for technical details and mod integration

[font=heading-1]
TODOs[/font]
See [a]here[/a]
[font=heading-1]
Dear supporters[/font]
[virtual-signal=signal-dot] Lukáš Venhoda (v0.2.0 update)

[font=heading-1]
Support fCPU[/font]
[[img]]==]
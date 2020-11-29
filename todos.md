# Upcoming  (in v0.4.x)
* Factorio v1.1.0 support.
* Multiple input/output wires.
* New graphics.

# Upcoming  (in v0.5.x)
* Hex number support.
* Test result flags to extend one condition line limitation.
* Logistics network access (@Chiko)
* Memory array with constant memory indices.
* Add push, pop, call, ret semantics for subroutines and stacks.

# Upcoming (in v0.6.x)
* Examples, demos and docs.
* Profiling & optimization (less ticks for `x*` operations).
* Mimic vanilla blueprint bahavior when stamped ontop of fCPU (copy blueprint program).

# TODO list, fCPU
* Asyncronous SIMD operations.
* Program library for storing subprograms outside of a fCPU units.
* Add drag and drop GUI for newbies.
* Code highlighting.
* Factorio modules support.
* Multiplayer glitch (https://discord.com/channels/705695217512349768/749054693581520996/779943947203510272)
* Extensions (https://discord.com/channels/705695217512349768/749028842869489776/781944420189863948, https://discord.com/channels/705695217512349768/749054693581520996/782674502601408524)
* Inline arithmetics (ipt+2, etc...).


# Done
* Output multiple signals (DONE in v0.2.0)
* `Informatron` support (DONE in v0.2.7)
* `Booktorio` support (DONE in v0.2.8)
* Memory browser for SIMD instructions (DONE in v0.3.0)
* Single instruction, multiple data - SIMD (DONE in v0.3.0)
* New `xmin`, `xmax`, `xavg`, `fim`, `rnd` SIMD opcodes (DONE in v0.3.1)
* Increase lines count, implement modern blueprint tags (DONE in v0.3.1)
* Extend x* semantics for copying registers and composing memory with separate signals (DONE in v0.3.9)
* Breakpoints (DONE in v0.4.0)
* Hotkeys, auto switch memory channel for debugging (DONE in v0.4.0)
* New conditional break until signal of a certain type has changed its value (DONE in v0.4.0)
* SIMD `x*` with 3 arguments (DONE in v0.4.0)
* `xflt` mnemonic for filtering signals (DONE in v0.4.0)
* Vector compare mnemonics `xc*` (DONE in v0.4.0)
* Being able to give a name/label to each processor (DONE in v0.4.0)

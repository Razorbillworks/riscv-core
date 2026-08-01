# riscv-core

A RISC-V CPU built in Verilog, going from a single-cycle datapath to a
5-stage pipeline, with a focus on branch prediction - comparing a classical
predictor (gshare) against a perceptron-based predictor, both implemented
as synthesizable RTL, with real gate-count/timing numbers from synthesis
(Yosys).

Built while working through Princeton's Computer Architecture course
(Coursera, David Wentzlaff) as a way to apply the pipelining/hazard/
branch-prediction concepts in actual hardware rather than just simulation.

## Why

Most student branch-predictor comparisons are software simulations. This
project implements predictors as real RTL and synthesizes them, so the
comparison isn't just "which predicts better" but "what does the better
predictor actually cost in gates and timing."

## Status

- [x] ALU
- [x] Register file
- [x] Instruction memory + decoder (10-instruction RV32I subset: add, sub,
      and, or, slt, addi, lw, sw, beq, jal)
- [x] Data memory
- [x] Single-cycle CPU — wired end-to-end, verified against a test program
- [x] 5-stage pipeline conversion
- [x] Hazard detection + stalling
- [x] Forwarding
- [x] Gshare branch predictor (RTL)
- [x] Perceptron branch predictor (RTL)
- [ ] Synthesis + gate count/timing comparison

Note: perceptron predictor is built, unit-tested, and wired into a
separate CPU variant (cpu_pipelined_perceptron.v) alongside the existing
gshare version, so both can be compared directly. Real measured results:
perceptron scores 90% prediction accuracy vs gshare's 74% on identical
training data, and the perceptron CPU completes the loop test program in
31 cycles vs gshare's 37 (~16% fewer cycles) — both verified
independently on two machines. Next and final step: synthesis (Yosys)
comparison of both predictors for real gate count and timing numbers.

## Instruction subset

R-type: `add sub and or slt`
I-type: `addi lw`
S-type: `sw`
B-type: `beq`
J-type: `jal`

## Structure

```
rtl/    - synthesizable Verilog modules
tb/     - testbenches (simulation only, not synthesizable)
scripts/ - helper scripts (test program assembler, etc.)
docs/   - notes, diagrams
```

## Running the tests

Requires Icarus Verilog (`iverilog`/`vvp`).

```bash
cd rtl
iverilog -o sim_cpu alu.v regfile.v imem.v decoder.v dmem.v cpu.v ../tb/cpu_tb.v
cp program.hex ..   # imem reads program.hex from the run directory
cd .. && vvp sim_cpu
```

Individual module testbenches (`alu_tb.v`, `regfile_tb.v`, `decoder_tb.v`)
can be run the same way against just their module.

## Toolchain

- [Icarus Verilog](http://iverilog.icarus.com/) — simulation
- [Yosys](https://yosyshq.net/yosys/) — synthesis (used later for the
  predictor comparison)

Both are free/open-source and install via `apt` on Linux, `brew` on macOS,
or prebuilt binaries on Windows.

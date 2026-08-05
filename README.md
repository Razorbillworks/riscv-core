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
- [x] Synthesis + gate count / timing comparison

Note: project complete. Full comparison across three metrics, gshare vs
perceptron, both fully integrated into working RTL CPUs:

| Metric              | gshare | perceptron |
|----------------------|--------|------------|
| Prediction accuracy  | 74%    | 90%        |
| Cycles (loop test)   | 37     | 31         |
| Gate count (Yosys)   | ~7,400 | ~420,000   |

Perceptron predicts better and runs faster, at a real and substantial
hardware cost (~57x more gates) - see synth/SYNTHESIS_RESULTS.md for the
full writeup, including why the gap is this large (not a coding mistake:
verified by right-sizing the accumulator first, which barely changed the
result). This is the real tradeoff branch predictor design has to
navigate, and it's why simpler counter-based predictors like gshare
remain common in practice despite being less accurate.

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

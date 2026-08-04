# Synthesis Results: gshare vs. perceptron

Both branch predictors were synthesized independently using Yosys's
generic technology-mapping flow (`proc; opt; memory; opt; techmap; opt`).
This maps behavioral Verilog down to a real gate-level netlist using
Yosys's built-in generic cell library. The absolute numbers below
wouldn't match a specific real silicon process (that would require a
real standard-cell library, e.g. via an open PDK), but the RELATIVE
comparison between the two predictors — synthesized identically, same
flow, same tool — is a fair, apples-to-apples basis for comparison,
which is the actual question this project is trying to answer.

## Results

| Predictor  | Total cells | AND    | OR      | MUX     | NOT    | XOR   | DFF (flip-flops) |
|------------|-------------|--------|---------|---------|--------|-------|-------------------|
| gshare     | 7,389       | 1,330  | 2,401   | 2,583   | 537    | 18    | 520               |
| perceptron | 420,296     | 84,830 | 109,824 | 208,992 | 10,843 | 1,191 | 4,616             |

**Perceptron costs roughly 57x more gates than gshare** in this
synthesis flow — genuinely large, and worth understanding *why*, not
just reporting the number.

## Why the gap is this large

The dominant cost is `$_MUX_` cells: gshare uses 2,583, perceptron uses
208,992 — over 80 times more, and by far the largest single category for
perceptron. This isn't a bug or a sizing mistake (we specifically checked
this — narrowing the accumulator from 32 bits down to a right-sized ~14
bits changed the total cell count by less than 1%, from 424,628 to
420,296, confirming the accumulator width was NOT the driver).

The real cause is structural: gshare's table stores one 2-bit counter per
entry (2 bits × 256 entries with HISTORY_BITS=8). Perceptron's table
stores a full weight VECTOR per entry — 9 weights (8 history weights +
1 bias) × 8 bits = 72 bits per entry × 64 entries. Both predictors read
this table using a runtime-variable index (derived from the PC), in
COMBINATIONAL logic, for TWO separate access paths every cycle (one for
prediction, one for the update/training path). Synthesizing "select one
of N wide entries based on a variable index, combinationally" fundamentally
requires large multiplexer trees, and perceptron's much wider per-entry
storage (72 bits vs. gshare's 2 bits) multiplies that cost substantially.

This matches real computer architecture research: perceptron predictors
are documented to require significantly more storage and more complex
access hardware than simple saturating-counter schemes like gshare. Our
synthesis results are an independent, hands-on confirmation of that
known tradeoff, not a surprising or anomalous result.

## The actual tradeoff this project demonstrates

- **Prediction accuracy:** perceptron 90% vs. gshare 74% (same training
  data, see `perceptron_predictor_tb.v` / `gshare_predictor_tb.v`)
- **Cycle count on a real loop program:** perceptron 31 cycles vs.
  gshare's 37 cycles (~16% fewer), verified on real RTL running an
  actual program (see `cpu_loop_tb.v` / `cpu_loop_perceptron_tb.v`)
- **Hardware cost:** perceptron ~57x more gates than gshare (this
  document)

This is the real engineering tradeoff branch predictor design has to
navigate: perceptron predicts meaningfully better, but at a real, large
hardware cost — which is exactly why simpler schemes like gshare remain
common in practice despite being less accurate, and why more storage-
efficient variants of perceptron prediction are an active research area.

## Reproducing these results

```bash
cd synth
yosys synth_gshare.ys      # takes a few seconds
yosys synth_perceptron.ys  # takes several minutes, ~1.5GB memory
```

Both scripts print a `stat` report with the full cell breakdown, and
write out a synthesized gate-level netlist (not committed to this repo
due to file size — the perceptron netlist alone is ~63MB).

// gshare_predictor.v
// Gshare branch predictor: predicts taken/not-taken using a table of 2-bit
// saturating counters, indexed by XOR-ing part of the PC with a global
// history register (a shift register recording the outcome of recent
// branches). The XOR is what "gshare" means — it lets the SAME table
// entry capture correlation between a branch's own recent behavior AND
// what other nearby branches have been doing, which plain per-PC counters
// (like counter_predictor.hpp in our earlier software version) cannot.
//
// This module is PURELY the predictor — it doesn't know what a "branch"
// or "PC" means architecturally, it just takes an address-like index,
// returns a prediction, and later gets told the real outcome to update
// itself. This keeps it decoupled from CPU internals so it can be reused,
// swapped, or compared against other predictors (like the perceptron
// version we build next) without touching the rest of the datapath.

module gshare_predictor #(
    parameter HISTORY_BITS = 8,           // width of global history register
    parameter TABLE_SIZE   = (1 << HISTORY_BITS)  // 2^HISTORY_BITS entries
) (
    input                      clk,
    input                      rst,

    // --- Prediction (combinational — must be available same cycle as
    //     the fetch, so the CPU can act on it immediately) ---
    input      [31:0]          pc,
    output                     predict_taken,

    // --- Update (called once we know the real outcome, typically in EX)
    //     ---
    input                      update_valid,   // 1 = a branch resolved this cycle, update the table
    input      [31:0]          update_pc,      // PC of the branch being updated
    input                      actual_taken    // the REAL outcome
);

    // The prediction table: one 2-bit saturating counter per entry.
    // 00/01 = predict not-taken, 10/11 = predict taken (classic 2-bit
    // saturating counter behavior, same as counter_predictor.hpp).
    reg [1:0] table_mem [0:TABLE_SIZE-1];

    // Global history: shift register of the last HISTORY_BITS branch
    // outcomes (1 = taken, 0 = not-taken), most recent in bit 0.
    reg [HISTORY_BITS-1:0] global_history;

    integer i;
    initial begin
        for (i = 0; i < TABLE_SIZE; i = i + 1)
            table_mem[i] = 2'b01; // start weakly-not-taken (a common,
                                   // reasonable default before any
                                   // training data exists)
        global_history = {HISTORY_BITS{1'b0}};
    end

    // --- Index computation ---
    // Use the low HISTORY_BITS of the PC (dropping the bottom 2 bits,
    // since instructions are word-aligned and those bits are always 0),
    // XOR'd with global history.
    wire [HISTORY_BITS-1:0] predict_index =
        pc[HISTORY_BITS+1:2] ^ global_history;

    assign predict_taken = table_mem[predict_index][1]; // MSB decides taken/not-taken

    // --- Update logic ---
    wire [HISTORY_BITS-1:0] update_index =
        update_pc[HISTORY_BITS+1:2] ^ global_history;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            global_history <= {HISTORY_BITS{1'b0}};
            // Note: we don't reset the whole table_mem array here (that's
            // what the `initial` block above is for, at simulation/power-on
            // time) — a synthesizable design typically wouldn't reset a
            // large table via reset logic anyway, as that would cost a lot
            // of extra gates for something that self-corrects via training
            // within a handful of branches regardless.
        end else if (update_valid) begin
            // Saturating counter update: increment toward 11 if taken,
            // decrement toward 00 if not-taken, but never wrap around.
            if (actual_taken) begin
                if (table_mem[update_index] != 2'b11)
                    table_mem[update_index] <= table_mem[update_index] + 2'b01;
            end else begin
                if (table_mem[update_index] != 2'b00)
                    table_mem[update_index] <= table_mem[update_index] - 2'b01;
            end

            // Shift the new outcome into global history.
            global_history <= {global_history[HISTORY_BITS-2:0], actual_taken};
        end
    end

endmodule

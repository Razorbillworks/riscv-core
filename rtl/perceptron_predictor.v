// perceptron_predictor.v
// Perceptron branch predictor (Jimenez & Lin style): instead of one 2-bit
// counter per table entry (gshare), each entry here is a small "neuron" —
// a vector of signed weights, one per bit of global history, plus a bias
// weight. Prediction is the SIGN of a weighted sum:
//
//   sum = bias + Σ (history[i] ? weight[i] : -weight[i])
//   predict_taken = (sum >= 0)
//
// Why no real multiplication: each history bit is binary (1=taken,
// 0=not-taken), which we treat as representing +1/-1 inputs to the
// neuron. Multiplying a weight by +1 or -1 is just "add the weight" or
// "subtract the weight" — this is the standard hardware trick that makes
// perceptron predictors synthesizable without needing real multipliers,
// which matters a lot for our later gate-count comparison against gshare.
//
// Training: whenever a branch resolves AND (we mispredicted OR the sum's
// magnitude was below a threshold — meaning the neuron wasn't confident),
// we nudge every weight toward the direction that would have helped:
// increment if history[i] agreed with the actual outcome, decrement if it
// disagreed. This is gradient-descent-flavored learning, done with simple
// saturating add/subtract instead of real floating-point math.

module perceptron_predictor #(
    parameter HISTORY_BITS  = 8,             // number of weights per neuron (excl. bias)
    parameter WEIGHT_WIDTH  = 8,              // bits per signed weight
    parameter INDEX_BITS    = 6,              // table size = 2^INDEX_BITS entries
    parameter TABLE_SIZE    = (1 << INDEX_BITS),
    parameter THRESHOLD     = 20              // train even on correct predictions below this confidence
) (
    input                          clk,
    input                          rst,

    input      [31:0]              pc,
    output                         predict_taken,

    input                          update_valid,
    input      [31:0]              update_pc,
    input                          actual_taken
);

    // Global history: same role as in gshare — shared across all
    // branches, shifted every time any branch resolves.
    reg [HISTORY_BITS-1:0] global_history;

    // Weight table: TABLE_SIZE neurons, each with HISTORY_BITS weights
    // plus 1 bias weight. Modeled as a 2D array: weights[entry][i].
    reg signed [WEIGHT_WIDTH-1:0] weights [0:TABLE_SIZE-1][0:HISTORY_BITS];
    // Note: index HISTORY_BITS (one past the last history weight) is used
    // as the bias term for that entry.

    integer e, w;
    initial begin
        for (e = 0; e < TABLE_SIZE; e = e + 1)
            for (w = 0; w <= HISTORY_BITS; w = w + 1)
                weights[e][w] = 0; // start neutral — no bias either direction
        global_history = {HISTORY_BITS{1'b0}};
    end

    wire [INDEX_BITS-1:0] predict_index = pc[INDEX_BITS+1:2];

    // --- Prediction: compute the weighted sum combinationally ---
    // Using an explicit always @(*) block (rather than a function called
    // from a continuous assignment) to compute this — some simulators
    // don't reliably re-trigger a `wire = function(...)` assignment when
    // the function reads a module-level array like `weights` that isn't
    // one of its passed-in arguments, even though the array read should
    // logically be part of its sensitivity. An explicit always @(*) block
    // sidesteps that entirely and is the more standard synthesizable style
    // anyway.
    reg signed [31:0] predict_sum;
    integer k;
    always @(*) begin
        predict_sum = weights[predict_index][HISTORY_BITS]; // start with bias
        for (k = 0; k < HISTORY_BITS; k = k + 1) begin
            if (global_history[k])
                predict_sum = predict_sum + weights[predict_index][k];
            else
                predict_sum = predict_sum - weights[predict_index][k];
        end
    end

    assign predict_taken = (predict_sum >= 0);

    // --- Update ---
    wire [INDEX_BITS-1:0] update_index = update_pc[INDEX_BITS+1:2];

    reg signed [31:0] update_sum;
    integer m;
    always @(*) begin
        update_sum = weights[update_index][HISTORY_BITS];
        for (m = 0; m < HISTORY_BITS; m = m + 1) begin
            if (global_history[m])
                update_sum = update_sum + weights[update_index][m];
            else
                update_sum = update_sum - weights[update_index][m];
        end
    end

    wire update_mispredicted = (update_sum >= 0) != actual_taken;
    wire abs_below_threshold = (update_sum < THRESHOLD) && (update_sum > -THRESHOLD);
    wire should_train = update_mispredicted || abs_below_threshold;

    integer u;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            global_history <= {HISTORY_BITS{1'b0}};
            // (table weights reset only at simulation start via `initial`,
            // same reasoning as gshare's table — resetting a large array
            // via the reset signal would cost real, unnecessary gates)
        end else if (update_valid) begin
            if (should_train) begin
                // Bias: nudge toward whatever the actual outcome was.
                if (actual_taken) begin
                    if (weights[update_index][HISTORY_BITS] < (2**(WEIGHT_WIDTH-1))-1)
                        weights[update_index][HISTORY_BITS] <= weights[update_index][HISTORY_BITS] + 1;
                end else begin
                    if (weights[update_index][HISTORY_BITS] > -(2**(WEIGHT_WIDTH-1)))
                        weights[update_index][HISTORY_BITS] <= weights[update_index][HISTORY_BITS] - 1;
                end

                // Each history weight: increment if that history bit
                // "agreed" with the real outcome, decrement if it didn't
                // — this is what teaches the neuron which past branches
                // actually correlate with this one.
                for (u = 0; u < HISTORY_BITS; u = u + 1) begin
                    if (global_history[u] == actual_taken) begin
                        if (weights[update_index][u] < (2**(WEIGHT_WIDTH-1))-1)
                            weights[update_index][u] <= weights[update_index][u] + 1;
                    end else begin
                        if (weights[update_index][u] > -(2**(WEIGHT_WIDTH-1)))
                            weights[update_index][u] <= weights[update_index][u] - 1;
                    end
                end
            end

            global_history <= {global_history[HISTORY_BITS-2:0], actual_taken};
        end
    end

endmodule

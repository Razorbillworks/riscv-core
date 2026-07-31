// gshare_predictor_tb.v
`timescale 1ns/1ps

module gshare_predictor_tb;

    reg         clk, rst;
    reg  [31:0] pc;
    wire        predict_taken;
    reg         update_valid;
    reg  [31:0] update_pc;
    reg         actual_taken;

    gshare_predictor #(.HISTORY_BITS(4)) uut (
        .clk(clk), .rst(rst),
        .pc(pc), .predict_taken(predict_taken),
        .update_valid(update_valid), .update_pc(update_pc), .actual_taken(actual_taken)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer i;
    integer correct_predictions = 0;
    integer total_predictions = 0;

    // Simulates training a SINGLE branch address that is taken 9 times out
    // of every 10 (like a loop that runs 9 iterations then exits) — same
    // shape of test as the branch-predictor-arena sample_loop.trace we
    // built earlier, just now against real RTL instead of a C++ model.
    task train_and_check(input [31:0] branch_pc, input actual);
        begin
            @(negedge clk);
            pc = branch_pc;
            #1; // let combinational prediction settle
            total_predictions = total_predictions + 1;
            if (predict_taken == actual)
                correct_predictions = correct_predictions + 1;

            // Now report the real outcome so the predictor learns
            update_valid = 1;
            update_pc = branch_pc;
            actual_taken = actual;
            @(posedge clk);
            #1;
            update_valid = 0;
        end
    endtask

    initial begin
        clk = 0; rst = 1; update_valid = 0;
        @(negedge clk); rst = 0;

        // Train on a loop-like pattern: taken 9x, not-taken 1x, repeated
        // several times, at a FIXED pc so the predictor can specialize.
        for (i = 0; i < 5; i = i + 1) begin
            train_and_check(32'h1000, 1); // taken
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 1);
            train_and_check(32'h1000, 0); // loop exit
        end

        $display("Correct predictions: %0d / %0d (%.1f%%)",
            correct_predictions, total_predictions,
            (correct_predictions * 100.0) / total_predictions);

        // After training, accuracy should be well above 50% (a dumb
        // coin-flip baseline) — a 2-bit counter on this pattern should
        // settle into correctly predicting "taken" most of the time,
        // only missing right around the loop-exit transition.
        if (correct_predictions * 100 < total_predictions * 70) begin
            $display("FAIL: predictor did not learn the pattern well (expected >=70%% accuracy)");
            errors = errors + 1;
        end else begin
            $display("PASS: predictor learned the loop pattern (>=70%% accuracy)");
        end

        // Sanity check: gshare's global history is SHARED across all
        // branches by design (that's the whole point — it lets one
        // branch's prediction be influenced by others nearby). This means
        // training two different PCs back-to-back will NOT keep them
        // independent, since global history keeps shifting between them.
        // To fairly test "does this PC's own address correctly influence
        // its prediction," we reset history between the two, isolating
        // each case rather than expecting cross-PC independence gshare
        // never promised in the first place.
        rst = 1; @(negedge clk); rst = 0;
        train_and_check(32'h1010, 1);
        train_and_check(32'h1010, 1);
        train_and_check(32'h1010, 1);
        pc = 32'h1010; #1;
        if (predict_taken !== 1'b1) begin
            $display("FAIL: expected pc=0x1010 to predict taken after 3x taken training");
            errors = errors + 1;
        end else begin
            $display("PASS: pc=0x1010 correctly predicts taken");
        end

        rst = 1; @(negedge clk); rst = 0;
        train_and_check(32'h1020, 0);
        train_and_check(32'h1020, 0);
        train_and_check(32'h1020, 0);
        pc = 32'h1020; #1;
        if (predict_taken !== 1'b0) begin
            $display("FAIL: expected pc=0x1020 to predict not-taken after 3x not-taken training");
            errors = errors + 1;
        end else begin
            $display("PASS: pc=0x1020 correctly predicts not-taken");
        end

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

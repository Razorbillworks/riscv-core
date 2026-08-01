// btb_tb.v
`timescale 1ns/1ps

module btb_tb;

    reg         clk, rst;
    reg  [31:0] fetch_pc;
    wire        btb_hit;
    wire [31:0] predicted_target;
    reg         update_valid, update_taken;
    reg  [31:0] update_pc, update_target;

    btb #(.INDEX_BITS(4)) uut (
        .clk(clk), .rst(rst),
        .fetch_pc(fetch_pc), .btb_hit(btb_hit), .predicted_target(predicted_target),
        .update_valid(update_valid), .update_pc(update_pc),
        .update_target(update_target), .update_taken(update_taken)
    );

    always #5 clk = ~clk;

    integer errors = 0;

    initial begin
        clk = 0; rst = 1; update_valid = 0;
        @(negedge clk); rst = 0;

        // Before any training: should miss
        fetch_pc = 32'h1000;
        #1;
        if (btb_hit !== 1'b0) begin
            $display("FAIL: expected miss before any training");
            errors = errors + 1;
        end else begin
            $display("PASS: miss before training, as expected");
        end

        // Train: branch at 0x1000 was taken, targeting 0x2000
        update_valid = 1; update_taken = 1;
        update_pc = 32'h1000; update_target = 32'h2000;
        @(posedge clk); #1;
        update_valid = 0;

        // Now look it up again: should hit, with the right target
        fetch_pc = 32'h1000;
        #1;
        if (btb_hit !== 1'b1 || predicted_target !== 32'h2000) begin
            $display("FAIL: expected hit with target=0x2000, got hit=%b target=%h",
                btb_hit, predicted_target);
            errors = errors + 1;
        end else begin
            $display("PASS: correct hit after training, target=0x2000");
        end

        // Different PC that was never trained, but maps to the SAME table
        // index (since INDEX_BITS=4, index = pc[5:2]; 0x1000 has bits[5:2]
        // = 0000, so 0x5000 -- also 0000 in those bits -- aliases to the
        // same table slot). The tag check should prevent a false hit.
        fetch_pc = 32'h5000;
        #1;
        if (btb_hit !== 1'b0) begin
            $display("FAIL: expected miss for aliasing PC with different tag, got hit=%b", btb_hit);
            errors = errors + 1;
        end else begin
            $display("PASS: tag mismatch correctly prevents false hit on aliasing address");
        end

        // A not-taken update should NOT invalidate an existing entry
        update_valid = 1; update_taken = 0;
        update_pc = 32'h1000; update_target = 32'h9999; // shouldn't matter, not taken
        @(posedge clk); #1;
        update_valid = 0;

        fetch_pc = 32'h1000;
        #1;
        if (btb_hit !== 1'b1 || predicted_target !== 32'h2000) begin
            $display("FAIL: not-taken update should not have disturbed cached entry, got hit=%b target=%h",
                btb_hit, predicted_target);
            errors = errors + 1;
        end else begin
            $display("PASS: not-taken update correctly left cached entry untouched");
        end

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

// cpu_loop_perceptron_tb.v
// Runs the loop test program to completion, checks final register state,
// and counts how many cycles it took. Cycle count is what we'll later use
// to compare "prediction on" vs "prediction off" (or gshare vs perceptron)
// — for now, this just establishes a correctness baseline and a cycle
// count we can reference later.

`timescale 1ns/1ps

module cpu_loop_perceptron_tb;

    reg clk, rst;
    integer cycle_count;

    cpu_pipelined_perceptron uut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    reg found_completion;
    integer completion_cycle;

    always @(posedge clk) begin
        if (!rst) begin
            cycle_count = cycle_count + 1;
            if (!found_completion && uut.regfile_inst.regs[4] == 32'd42) begin
                found_completion = 1'b1;
                completion_cycle = cycle_count;
            end
        end
    end

    integer errors = 0;

    task check_reg(input [4:0] reg_num, input [31:0] expected, input [200*8-1:0] label);
        begin
            if (uut.regfile_inst.regs[reg_num] !== expected) begin
                $display("FAIL: %0s | x%0d expected=%0d got=%0d",
                    label, reg_num, expected, uut.regfile_inst.regs[reg_num]);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s | x%0d = %0d", label, reg_num, expected);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; cycle_count = 0; found_completion = 1'b0; completion_cycle = 0;
        @(negedge clk); rst = 0;

        // Run generously long enough for the loop (5 iterations) plus
        // pipeline fill/drain plus any misprediction flush penalties.
        repeat (60) @(negedge clk);

        $display("--- Loop program results ---");
        check_reg(1, 32'd5, "x1 = final loop counter (should stop at 5)");
        check_reg(2, 32'd5, "x2 = loop limit");
        check_reg(3, 32'd0, "x3 = (5<5) = false = 0, from the FINAL slt before exit");
        check_reg(4, 32'd42, "x4 = exit marker (proves we reached exit code correctly)");

        $display("\nProgram completed in %0d cycles (first cycle x4 read 42)", completion_cycle);
        $display("(Reference point for later prediction-strategy comparisons)");

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

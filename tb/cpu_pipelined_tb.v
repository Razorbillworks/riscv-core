// cpu_pipelined_tb.v
// Runs the same test program as the single-cycle CPU. We EXPECT some
// checks to fail here — this pipeline has no hazard detection or
// forwarding yet, so instructions that depend on very recent results will
// read stale (old) register values. Any failures here confirm we've
// correctly identified the hazard problem; the next step is fixing it.

`timescale 1ns/1ps

module cpu_pipelined_tb;

    reg clk, rst;

    cpu_pipelined uut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    task show_reg(input [4:0] reg_num, input [200*8-1:0] label);
        begin
            $display("x%0d (%0s) = %0d", reg_num, label, uut.regfile_inst.regs[reg_num]);
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        @(negedge clk);
        rst = 0;

        // Pipeline needs extra cycles vs single-cycle: an instruction now
        // takes 5 cycles to fully complete (though one finishes per cycle
        // once the pipeline is full), so give it more time overall.
        repeat (40) @(negedge clk);

        $display("--- Register state after running test program on PIPELINED cpu (no hazard handling) ---");
        show_reg(1, "addi x1,x0,5");
        show_reg(2, "addi x2,x0,3");
        show_reg(3, "add x3,x1,x2 -- expect WRONG: x1/x2 not written back yet when this executes");
        show_reg(4, "sub x4,x1,x2 -- likely also WRONG for same reason");
        show_reg(5, "lw x5,0(x0) after sw x3 -- likely WRONG, depends on x3 AND mem write timing");
        show_reg(6, "should be 0 (skipped by branch, if branching even works here)");
        show_reg(7, "addi x7,x0,7 (branch target) -- may not even land here without flush logic");
        show_reg(8, "and x8,x1,x2");
        show_reg(9, "or x9,x1,x2");
        show_reg(10, "slt x10,x2,x1");

        $display("\nThis output is for observation, not pass/fail — see accompanying notes.");
        $finish;
    end

endmodule

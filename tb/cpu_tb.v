// cpu_tb.v
`timescale 1ns/1ps

module cpu_tb;

    reg clk, rst;

    cpu uut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    integer errors = 0;

    // Peek directly into the regfile and dmem arrays for checking —
    // hierarchical references like this are a simulation-only convenience
    // (you couldn't do this on real silicon, but it's normal/expected in
    // a testbench).
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
        clk = 0;
        rst = 1;
        @(negedge clk);
        rst = 0;

        // Run for enough cycles to execute all 9 real instructions
        // (12 written, but beq skips one, so 11 actually execute)
        repeat (15) @(negedge clk);

        $display("\n--- Register checks ---");
        check_reg(1, 32'd5, "addi x1,x0,5");
        check_reg(2, 32'd3, "addi x2,x0,3");
        check_reg(3, 32'd8, "add x3,x1,x2");
        check_reg(4, 32'd2, "sub x4,x1,x2");
        check_reg(5, 32'd8, "lw x5,0(x0) after sw x3");
        check_reg(6, 32'd0, "x6 should be untouched (beq skipped the addi that would set it)");
        check_reg(7, 32'd7, "addi x7,x0,7 (branch target)");
        check_reg(8, 32'd1, "and x8,x1,x2 = 5&3");
        check_reg(9, 32'd7, "or x9,x1,x2 = 5|3");
        check_reg(10, 32'd1, "slt x10,x2,x1 = (3<5)");

        $display("\n--- Memory check ---");
        if (uut.dmem_inst.mem[0] !== 32'd8) begin
            $display("FAIL: mem[0] expected=8 got=%0d", uut.dmem_inst.mem[0]);
            errors = errors + 1;
        end else begin
            $display("PASS: mem[0] = 8 (from sw x3,0(x0))");
        end

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

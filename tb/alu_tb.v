// alu_tb.v
// Testbench: not synthesizable hardware, just a script that drives inputs
// into the ALU and checks outputs against expected values.

`timescale 1ns/1ps

module alu_tb;

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    // Instantiate the ALU (this is how you "use" a module — wire its ports
    // to signals in the testbench)
    alu uut (
        .a(a),
        .b(b),
        .alu_ctrl(alu_ctrl),
        .result(result),
        .zero(zero)
    );

    integer errors = 0;

    task check(input [31:0] expected, input [200*8-1:0] label);
        begin
            if (result !== expected) begin
                $display("FAIL: %0s | expected=%0d got=%0d", label, expected, result);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s | result=%0d", label, result);
            end
        end
    endtask

    initial begin
        // ADD: 5 + 3 = 8
        a = 32'd5; b = 32'd3; alu_ctrl = 4'b0000; #1;
        check(32'd8, "ADD 5+3");

        // SUB: 10 - 4 = 6
        a = 32'd10; b = 32'd4; alu_ctrl = 4'b0001; #1;
        check(32'd6, "SUB 10-4");

        // AND: 0xF0 & 0x3C = 0x30
        a = 32'hF0; b = 32'h3C; alu_ctrl = 4'b0010; #1;
        check(32'h30, "AND 0xF0&0x3C");

        // OR: 0xF0 | 0x0F = 0xFF
        a = 32'hF0; b = 32'h0F; alu_ctrl = 4'b0011; #1;
        check(32'hFF, "OR 0xF0|0x0F");

        // SLT: -1 < 1 -> true (signed comparison)
        a = -32'd1; b = 32'd1; alu_ctrl = 4'b0100; #1;
        check(32'd1, "SLT -1<1 (signed)");

        // SLT: 5 < 3 -> false
        a = 32'd5; b = 32'd3; alu_ctrl = 4'b0100; #1;
        check(32'd0, "SLT 5<3");

        // zero flag check: 4 - 4 = 0
        a = 32'd4; b = 32'd4; alu_ctrl = 4'b0001; #1;
        if (zero !== 1'b1) begin
            $display("FAIL: zero flag not set for 4-4");
            errors = errors + 1;
        end else begin
            $display("PASS: zero flag set for 4-4");
        end

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

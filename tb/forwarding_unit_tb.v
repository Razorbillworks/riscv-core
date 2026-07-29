// forwarding_unit_tb.v
`timescale 1ns/1ps

module forwarding_unit_tb;

    reg  [4:0] ex_rs1_addr, ex_rs2_addr, mem_rd_addr, wb_rd_addr;
    reg        mem_reg_write, wb_reg_write;
    wire [1:0] forward_a, forward_b;

    forwarding_unit uut (
        .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),
        .mem_rd_addr(mem_rd_addr), .mem_reg_write(mem_reg_write),
        .wb_rd_addr(wb_rd_addr), .wb_reg_write(wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    integer errors = 0;

    task check(input [1:0] a_expected, input [1:0] b_expected, input [200*8-1:0] label);
        begin
            if (forward_a !== a_expected || forward_b !== b_expected) begin
                $display("FAIL: %0s | expected a=%b b=%b, got a=%b b=%b",
                    label, a_expected, b_expected, forward_a, forward_b);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s | a=%b b=%b", label, forward_a, forward_b);
            end
        end
    endtask

    initial begin
        // No hazard: nothing matches
        ex_rs1_addr = 5'd1; ex_rs2_addr = 5'd2;
        mem_rd_addr = 5'd5; mem_reg_write = 1;
        wb_rd_addr  = 5'd6; wb_reg_write  = 1;
        #1; check(2'b00, 2'b00, "no hazard, no matching registers");

        // EX/MEM hazard on rs1
        ex_rs1_addr = 5'd5; ex_rs2_addr = 5'd2;
        mem_rd_addr = 5'd5; mem_reg_write = 1;
        wb_rd_addr  = 5'd6; wb_reg_write  = 1;
        #1; check(2'b10, 2'b00, "EX/MEM hazard on rs1");

        // MEM/WB hazard on rs2
        ex_rs1_addr = 5'd1; ex_rs2_addr = 5'd6;
        mem_rd_addr = 5'd5; mem_reg_write = 1;
        wb_rd_addr  = 5'd6; wb_reg_write  = 1;
        #1; check(2'b00, 2'b01, "MEM/WB hazard on rs2");

        // Both EX/MEM and MEM/WB target the SAME register as rs1 ->
        // EX/MEM should win (more recent result)
        ex_rs1_addr = 5'd7; ex_rs2_addr = 5'd2;
        mem_rd_addr = 5'd7; mem_reg_write = 1;
        wb_rd_addr  = 5'd7; wb_reg_write  = 1;
        #1; check(2'b10, 2'b00, "EX/MEM takes priority over MEM/WB on same reg");

        // x0 should never trigger forwarding even if rd_addr matches somehow
        ex_rs1_addr = 5'd0; ex_rs2_addr = 5'd0;
        mem_rd_addr = 5'd0; mem_reg_write = 1;
        wb_rd_addr  = 5'd0; wb_reg_write  = 1;
        #1; check(2'b00, 2'b00, "x0 never triggers forwarding");

        // reg_write = 0 means no real hazard even if addresses match
        // (e.g. a store instruction sitting in MEM/EX doesn't write a register)
        ex_rs1_addr = 5'd5; ex_rs2_addr = 5'd6;
        mem_rd_addr = 5'd5; mem_reg_write = 0;
        wb_rd_addr  = 5'd6; wb_reg_write  = 0;
        #1; check(2'b00, 2'b00, "reg_write=0 means no forwarding even if addr matches");

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

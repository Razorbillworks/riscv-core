// hazard_detection_unit_tb.v
`timescale 1ns/1ps

module hazard_detection_unit_tb;

    reg       ex_mem_read;
    reg [4:0] ex_rd_addr, id_rs1_addr, id_rs2_addr;
    wire      stall;

    hazard_detection_unit uut (
        .ex_mem_read(ex_mem_read), .ex_rd_addr(ex_rd_addr),
        .id_rs1_addr(id_rs1_addr), .id_rs2_addr(id_rs2_addr),
        .stall(stall)
    );

    integer errors = 0;

    task check(input expected, input [200*8-1:0] label);
        begin
            if (stall !== expected) begin
                $display("FAIL: %0s | expected=%b got=%b", label, expected, stall);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s | stall=%b", label, stall);
            end
        end
    endtask

    initial begin
        // Classic load-use: lw x1,... ; add x3,x1,x4
        ex_mem_read = 1; ex_rd_addr = 5'd1;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd4;
        #1; check(1'b1, "load-use hazard on rs1");

        // Load-use on rs2 instead
        ex_mem_read = 1; ex_rd_addr = 5'd4;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd4;
        #1; check(1'b1, "load-use hazard on rs2");

        // Not a load at all -> no stall even if regs match
        ex_mem_read = 0; ex_rd_addr = 5'd1;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd4;
        #1; check(1'b0, "not a load, no stall");

        // Load, but no register overlap -> no stall
        ex_mem_read = 1; ex_rd_addr = 5'd9;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd4;
        #1; check(1'b0, "load but no overlap, no stall");

        // Load targeting x0 -> never a real hazard
        ex_mem_read = 1; ex_rd_addr = 5'd0;
        id_rs1_addr = 5'd0; id_rs2_addr = 5'd0;
        #1; check(1'b0, "load to x0 never stalls");

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

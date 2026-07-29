// regfile_tb.v
`timescale 1ns/1ps

module regfile_tb;

    reg         clk;
    reg         we;
    reg  [4:0]  rs1_addr, rs2_addr, rd_addr;
    reg  [31:0] rd_data;
    wire [31:0] rs1_data, rs2_data;

    regfile uut (
        .clk(clk), .we(we),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    // Clock generator: toggle clk every 5ns -> 10ns period (100MHz notionally).
    // This is the standard Verilog idiom for generating a clock in simulation.
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors = 0;

    initial begin
        we = 0; rd_addr = 0; rd_data = 0; rs1_addr = 0; rs2_addr = 0;

        // Write 42 into x5 on a clock edge
        @(negedge clk); // wait for a safe point (clock low) before changing inputs
        we = 1; rd_addr = 5'd5; rd_data = 32'd42;
        @(posedge clk); // this is the edge that actually performs the write
        #1; // let it settle
        we = 0;

        // Read back x5
        rs1_addr = 5'd5;
        #1;
        if (rs1_data !== 32'd42) begin
            $display("FAIL: expected x5=42, got %0d", rs1_data);
            errors = errors + 1;
        end else begin
            $display("PASS: x5 correctly holds 42 after write");
        end

        // Write to x0 should be ignored
        @(negedge clk);
        we = 1; rd_addr = 5'd0; rd_data = 32'd999;
        @(posedge clk);
        #1;
        we = 0;
        rs1_addr = 5'd0;
        #1;
        if (rs1_data !== 32'd0) begin
            $display("FAIL: x0 should always read 0, got %0d", rs1_data);
            errors = errors + 1;
        end else begin
            $display("PASS: x0 stays hardwired to 0 even after write attempt");
        end

        // Dual-port read: read x5 and x0 simultaneously (rs1 and rs2)
        rs1_addr = 5'd5; rs2_addr = 5'd0;
        #1;
        if (rs1_data !== 32'd42 || rs2_data !== 32'd0) begin
            $display("FAIL: dual read incorrect, rs1=%0d rs2=%0d", rs1_data, rs2_data);
            errors = errors + 1;
        end else begin
            $display("PASS: dual-port read works (rs1=x5=42, rs2=x0=0)");
        end

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

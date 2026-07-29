// forwarding_unit.v
// Decides whether the EX stage's ALU operands should come from:
//   - the register file (normal case, no hazard)
//   - the EX/MEM pipeline register (result computed 1 cycle ago)
//   - the MEM/WB pipeline register (result computed 2 cycles ago)
//
// This is pure combinational logic — it just LOOKS at register numbers
// and produces a 2-bit "which source" signal per operand. The actual
// muxing happens back in the CPU top-level, using these signals.

module forwarding_unit (
    // Source registers needed by the instruction currently in EX
    input [4:0] ex_rs1_addr,
    input [4:0] ex_rs2_addr,

    // Destination register + write-enable of instruction in EX/MEM
    // (i.e. the instruction one stage ahead, result computed last cycle)
    input [4:0] mem_rd_addr,
    input       mem_reg_write,

    // Destination register + write-enable of instruction in MEM/WB
    // (result computed two cycles ago)
    input [4:0] wb_rd_addr,
    input       wb_reg_write,

    // 2-bit select per operand:
    //   00 = no forwarding, use register file value
    //   01 = forward from MEM/WB stage
    //   10 = forward from EX/MEM stage (higher priority — more recent)
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    always @(*) begin
        // --- forward_a: for rs1 ---
        // EX/MEM hazard check first (higher priority: more recent result).
        // We also check rd_addr != 0, since x0 is hardwired to zero and
        // writes to it should never be treated as a real hazard.
        if (mem_reg_write && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs1_addr))
            forward_a = 2'b10;
        else if (wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs1_addr))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // --- forward_b: for rs2, same logic ---
        if (mem_reg_write && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs2_addr))
            forward_b = 2'b10;
        else if (wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs2_addr))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule

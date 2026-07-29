// id_ex_reg.v
// Pipeline register between Decode and Execute stages.
//
// Decode produces a LOT of things: register values, the immediate, the
// destination register number, and every control signal the rest of the
// pipeline needs (alu_ctrl, mem_read, mem_write, etc). All of it has to be
// latched here so Execute has it available next cycle, even after Decode
// has moved on to the next instruction.

module id_ex_reg (
    input         clk,
    input         rst,

    // data values
    input  [31:0] pc_in,
    input  [31:0] rs1_data_in,
    input  [31:0] rs2_data_in,
    input  [31:0] imm_in,
    input  [4:0]  rs1_addr_in,
    input  [4:0]  rs2_addr_in,
    input  [4:0]  rd_addr_in,

    // control signals (produced by decoder, consumed by later stages)
    input  [3:0]  alu_ctrl_in,
    input         alu_src_in,
    input         reg_write_in,
    input         mem_read_in,
    input         mem_write_in,
    input         mem_to_reg_in,
    input         branch_in,
    input         jump_in,

    output reg [31:0] pc_out,
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [31:0] imm_out,
    output reg [4:0]  rs1_addr_out,
    output reg [4:0]  rs2_addr_out,
    output reg [4:0]  rd_addr_out,

    output reg [3:0]  alu_ctrl_out,
    output reg        alu_src_out,
    output reg        reg_write_out,
    output reg        mem_read_out,
    output reg        mem_write_out,
    output reg        mem_to_reg_out,
    output reg        branch_out,
    output reg        jump_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out         <= 32'd0;
            rs1_data_out   <= 32'd0;
            rs2_data_out   <= 32'd0;
            imm_out        <= 32'd0;
            rs1_addr_out   <= 5'd0;
            rs2_addr_out   <= 5'd0;
            rd_addr_out    <= 5'd0;
            alu_ctrl_out   <= 4'd0;
            alu_src_out    <= 1'b0;
            reg_write_out  <= 1'b0; // critical: on flush/reset, reg_write=0
                                     // means this "instruction" can never
                                     // corrupt the register file
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            branch_out     <= 1'b0;
            jump_out       <= 1'b0;
        end else begin
            pc_out         <= pc_in;
            rs1_data_out   <= rs1_data_in;
            rs2_data_out   <= rs2_data_in;
            imm_out        <= imm_in;
            rs1_addr_out   <= rs1_addr_in;
            rs2_addr_out   <= rs2_addr_in;
            rd_addr_out    <= rd_addr_in;
            alu_ctrl_out   <= alu_ctrl_in;
            alu_src_out    <= alu_src_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            branch_out     <= branch_in;
            jump_out       <= jump_in;
        end
    end

endmodule

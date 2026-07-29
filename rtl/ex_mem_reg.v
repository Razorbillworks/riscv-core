// ex_mem_reg.v
// Pipeline register between Execute and Memory stages.

module ex_mem_reg (
    input         clk,
    input         rst,

    input  [31:0] alu_result_in,
    input  [31:0] rs2_data_in,   // needed for sw (value to store)
    input  [4:0]  rd_addr_in,
    input  [31:0] pc_plus_4_in,  // needed for jal writeback

    input         reg_write_in,
    input         mem_read_in,
    input         mem_write_in,
    input         mem_to_reg_in,
    input         jump_in,

    output reg [31:0] alu_result_out,
    output reg [31:0] rs2_data_out,
    output reg [4:0]  rd_addr_out,
    output reg [31:0] pc_plus_4_out,

    output reg        reg_write_out,
    output reg        mem_read_out,
    output reg        mem_write_out,
    output reg        mem_to_reg_out,
    output reg        jump_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_result_out <= 32'd0;
            rs2_data_out   <= 32'd0;
            rd_addr_out    <= 5'd0;
            pc_plus_4_out  <= 32'd0;
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
            jump_out       <= 1'b0;
        end else begin
            alu_result_out <= alu_result_in;
            rs2_data_out   <= rs2_data_in;
            rd_addr_out    <= rd_addr_in;
            pc_plus_4_out  <= pc_plus_4_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            jump_out       <= jump_in;
        end
    end

endmodule

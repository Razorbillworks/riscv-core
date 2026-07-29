// mem_wb_reg.v
// Pipeline register between Memory and Writeback stages — the last one.

module mem_wb_reg (
    input         clk,
    input         rst,

    input  [31:0] alu_result_in,
    input  [31:0] mem_read_data_in,
    input  [31:0] pc_plus_4_in,
    input  [4:0]  rd_addr_in,

    input         reg_write_in,
    input         mem_to_reg_in,
    input         jump_in,

    output reg [31:0] alu_result_out,
    output reg [31:0] mem_read_data_out,
    output reg [31:0] pc_plus_4_out,
    output reg [4:0]  rd_addr_out,

    output reg        reg_write_out,
    output reg        mem_to_reg_out,
    output reg        jump_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_result_out    <= 32'd0;
            mem_read_data_out <= 32'd0;
            pc_plus_4_out     <= 32'd0;
            rd_addr_out       <= 5'd0;
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            jump_out          <= 1'b0;
        end else begin
            alu_result_out    <= alu_result_in;
            mem_read_data_out <= mem_read_data_in;
            pc_plus_4_out     <= pc_plus_4_in;
            rd_addr_out       <= rd_addr_in;
            reg_write_out     <= reg_write_in;
            mem_to_reg_out    <= mem_to_reg_in;
            jump_out          <= jump_in;
        end
    end

endmodule

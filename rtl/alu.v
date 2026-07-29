// alu.v
// Arithmetic Logic Unit — does the actual computation for add/sub/and/or/slt.
// Every instruction that computes something (R-type, I-type, and the address
// calc for lw/sw, and the comparison for beq) routes through this same unit.

module alu (
    input  [31:0] a,        // first operand
    input  [31:0] b,        // second operand
    input  [3:0]  alu_ctrl, // tells the ALU which operation to perform
    output reg [31:0] result,
    output        zero      // 1 if result == 0 (used for beq)
);

    // Operation encoding — arbitrary but fixed, decoder will produce these.
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_SLT = 4'b0100;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule

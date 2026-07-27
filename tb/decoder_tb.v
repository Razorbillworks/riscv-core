// decoder_tb.v
`timescale 1ns/1ps

module decoder_tb;

    reg  [31:0] instr;
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [31:0] imm;
    wire [3:0]  alu_ctrl;
    wire        alu_src, reg_write, mem_read, mem_write, mem_to_reg, branch, jump;

    decoder uut (
        .instr(instr),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr), .imm(imm),
        .alu_ctrl(alu_ctrl), .alu_src(alu_src), .reg_write(reg_write),
        .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump)
    );

    integer errors = 0;

    task check_bit(input actual, input expected, input [200*8-1:0] label);
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s | expected=%0b got=%0b", label, expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // add x1, x2, x3  ->  rd=1 rs1=2 rs2=3, opcode=0110011 funct3=000 funct7=0000000
        // encoding: funct7[6:0] rs2[4:0] rs1[4:0] funct3[2:0] rd[4:0] opcode[6:0]
        instr = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011};
        #1;
        check_bit(reg_write, 1, "add: reg_write");
        check_bit(alu_src, 0, "add: alu_src (uses two regs)");
        if (alu_ctrl !== 4'b0000) begin $display("FAIL: add alu_ctrl wrong, got %b", alu_ctrl); errors=errors+1; end
        if (rs1_addr !== 5'd2 || rs2_addr !== 5'd3 || rd_addr !== 5'd1) begin
            $display("FAIL: add field extraction wrong"); errors = errors + 1;
        end
        $display("checked: add x1,x2,x3");

        // sub x1, x2, x3 -> same as add but funct7[5]=1 (0100000)
        instr = {7'b0100000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011};
        #1;
        if (alu_ctrl !== 4'b0001) begin $display("FAIL: sub alu_ctrl wrong, got %b", alu_ctrl); errors=errors+1; end
        else $display("checked: sub x1,x2,x3 -> alu_ctrl=SUB");

        // addi x5, x6, 10 -> opcode=0010011, imm=10
        instr = {12'd10, 5'd6, 3'b000, 5'd5, 7'b0010011};
        #1;
        check_bit(reg_write, 1, "addi: reg_write");
        check_bit(alu_src, 1, "addi: alu_src (uses immediate)");
        if (imm !== 32'd10) begin $display("FAIL: addi imm wrong, got %0d", imm); errors=errors+1; end
        else $display("checked: addi x5,x6,10 -> imm=10");

        // lw x7, 8(x8) -> opcode=0000011, imm=8
        instr = {12'd8, 5'd8, 3'b010, 5'd7, 7'b0000011};
        #1;
        check_bit(mem_read, 1, "lw: mem_read");
        check_bit(mem_to_reg, 1, "lw: mem_to_reg");
        check_bit(reg_write, 1, "lw: reg_write");
        if (imm !== 32'd8) begin $display("FAIL: lw imm wrong, got %0d", imm); errors=errors+1; end
        else $display("checked: lw x7,8(x8)");

        // sw x9, 4(x10) -> opcode=0100011, S-type imm split across two fields
        // imm=4 -> imm[11:5]=0000000 imm[4:0]=00100
        instr = {7'b0000000, 5'd9, 5'd10, 3'b010, 5'b00100, 7'b0100011};
        #1;
        check_bit(mem_write, 1, "sw: mem_write");
        check_bit(reg_write, 0, "sw: does not write regfile");
        if (imm !== 32'd4) begin $display("FAIL: sw imm wrong, got %0d", imm); errors=errors+1; end
        else $display("checked: sw x9,4(x10)");

        // beq x1, x2, offset -> opcode=1100011
        instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'b00000, 7'b1100011};
        #1;
        check_bit(branch, 1, "beq: branch flag");
        check_bit(reg_write, 0, "beq: does not write regfile");
        if (alu_ctrl !== 4'b0001) begin $display("FAIL: beq should SUB for comparison"); errors=errors+1; end
        else $display("checked: beq x1,x2 -> branch=1, alu_ctrl=SUB");

        // jal x1, offset -> opcode=1101111
        instr = {1'b0, 10'b0000000000, 1'b0, 8'b00000000, 5'd1, 7'b1101111};
        #1;
        check_bit(jump, 1, "jal: jump flag");
        check_bit(reg_write, 1, "jal: writes return address to rd");
        $display("checked: jal x1 -> jump=1, reg_write=1");

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

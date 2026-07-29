// cpu_pipelined.v
// 5-stage pipelined RISC-V CPU: IF -> ID -> EX -> MEM -> WB.
//
// IMPORTANT: this version has NO hazard detection and NO forwarding yet.
// That means any program where one instruction needs a result from an
// instruction still "in flight" a few stages behind it will get WRONG
// answers here — the register file simply won't have the new value written
// back yet when the dependent instruction reads it. This is intentional:
// we're building the plain pipeline skeleton first so we can concretely
// SEE the hazard bug before fixing it with forwarding/stalling.

module cpu_pipelined (
    input clk,
    input rst
);

    // =========================================================
    // IF stage
    // =========================================================
    reg [31:0] pc;
    wire [31:0] if_instr;

    imem imem_inst (
        .addr(pc),
        .instr(if_instr)
    );

    wire [31:0] if_pc_plus_4 = pc + 32'd4;

    // next_pc is computed in EX stage (branch/jump decisions happen there),
    // fed back here. For now (no hazard handling), we just always fetch
    // sequentially unless EX says otherwise.
    wire [31:0] ex_next_pc; // driven from EX stage further down

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else
            pc <= ex_next_pc;
    end

    // =========================================================
    // IF/ID pipeline register
    // =========================================================
    wire [31:0] id_pc, id_instr;

    if_id_reg if_id (
        .clk(clk), .rst(rst),
        .pc_in(pc), .instr_in(if_instr),
        .pc_out(id_pc), .instr_out(id_instr)
    );

    // =========================================================
    // ID stage
    // =========================================================
    wire [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    wire [31:0] id_imm;
    wire [3:0]  id_alu_ctrl;
    wire        id_alu_src, id_reg_write, id_mem_read, id_mem_write,
                id_mem_to_reg, id_branch, id_jump;

    decoder decoder_inst (
        .instr(id_instr),
        .rs1_addr(id_rs1_addr), .rs2_addr(id_rs2_addr), .rd_addr(id_rd_addr),
        .imm(id_imm),
        .alu_ctrl(id_alu_ctrl), .alu_src(id_alu_src), .reg_write(id_reg_write),
        .mem_read(id_mem_read), .mem_write(id_mem_write), .mem_to_reg(id_mem_to_reg),
        .branch(id_branch), .jump(id_jump)
    );

    wire [31:0] id_rs1_data, id_rs2_data;
    wire [31:0] wb_write_back_data; // driven from WB stage further down
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write;

    regfile regfile_inst (
        .clk(clk),
        .we(wb_reg_write),
        .rs1_addr(id_rs1_addr), .rs2_addr(id_rs2_addr), .rd_addr(wb_rd_addr),
        .rd_data(wb_write_back_data),
        .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );

    // =========================================================
    // ID/EX pipeline register
    // =========================================================
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    wire [3:0]  ex_alu_ctrl;
    wire        ex_alu_src, ex_reg_write, ex_mem_read, ex_mem_write,
                ex_mem_to_reg, ex_branch, ex_jump;

    id_ex_reg id_ex (
        .clk(clk), .rst(rst),
        .pc_in(id_pc), .rs1_data_in(id_rs1_data), .rs2_data_in(id_rs2_data),
        .imm_in(id_imm), .rs1_addr_in(id_rs1_addr), .rs2_addr_in(id_rs2_addr),
        .rd_addr_in(id_rd_addr),
        .alu_ctrl_in(id_alu_ctrl), .alu_src_in(id_alu_src), .reg_write_in(id_reg_write),
        .mem_read_in(id_mem_read), .mem_write_in(id_mem_write), .mem_to_reg_in(id_mem_to_reg),
        .branch_in(id_branch), .jump_in(id_jump),

        .pc_out(ex_pc), .rs1_data_out(ex_rs1_data), .rs2_data_out(ex_rs2_data),
        .imm_out(ex_imm), .rs1_addr_out(ex_rs1_addr), .rs2_addr_out(ex_rs2_addr),
        .rd_addr_out(ex_rd_addr),
        .alu_ctrl_out(ex_alu_ctrl), .alu_src_out(ex_alu_src), .reg_write_out(ex_reg_write),
        .mem_read_out(ex_mem_read), .mem_write_out(ex_mem_write), .mem_to_reg_out(ex_mem_to_reg),
        .branch_out(ex_branch), .jump_out(ex_jump)
    );

    // =========================================================
    // EX stage
    // =========================================================

    // --- Forwarding ---
    // Check whether the values we need (ex_rs1_data / ex_rs2_data, latched
    // from the register file back in ID) are actually STALE — i.e. an
    // instruction ahead of us in EX/MEM or MEM/WB is about to write the
    // same register we need, but hasn't reached the register file yet.
    wire [1:0] forward_a, forward_b;

    forwarding_unit forwarding_unit_inst (
        .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),
        .mem_rd_addr(mem_rd_addr), .mem_reg_write(mem_reg_write),
        .wb_rd_addr(wb_rd_addr), .wb_reg_write(wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    // Mux: pick the ACTUAL value to feed the ALU, based on forwarding_unit's
    // decision. 2'b10 = take from EX/MEM (mem_alu_result), 2'b01 = take
    // from MEM/WB (wb_write_back_data, already muxed for us below), 2'b00 =
    // no hazard, use the value latched from the register file.
    wire [31:0] ex_rs1_data_fwd = (forward_a == 2'b10) ? mem_alu_result :
                                  (forward_a == 2'b01) ? wb_write_back_data :
                                                          ex_rs1_data;
    wire [31:0] ex_rs2_data_fwd = (forward_b == 2'b10) ? mem_alu_result :
                                  (forward_b == 2'b01) ? wb_write_back_data :
                                                          ex_rs2_data;

    wire [31:0] ex_alu_operand_a = ex_rs1_data_fwd;
    wire [31:0] ex_alu_operand_b = ex_alu_src ? ex_imm : ex_rs2_data_fwd;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;

    alu alu_inst (
        .a(ex_alu_operand_a),
        .b(ex_alu_operand_b),
        .alu_ctrl(ex_alu_ctrl),
        .result(ex_alu_result),
        .zero(ex_alu_zero)
    );

    wire [31:0] ex_pc_plus_4 = ex_pc + 32'd4;
    wire        ex_branch_taken = ex_branch & ex_alu_zero;
    wire [31:0] ex_branch_target = ex_pc + ex_imm;

    // This feeds back to the PC mux in IF stage (declared as ex_next_pc above).
    // IMPORTANT: the default (non-branch/jump) case must use the CURRENT
    // fetch-stage PC+4 (if_pc_plus_4), not ex_pc+4. ex_pc is a delayed copy
    // (2 cycles old, latched back in ID/EX) — using it as the default would
    // make PC advance at the wrong rate and desync the whole pipeline. It's
    // only correct to use EX's own PC when EX is actively overriding fetch
    // with a branch/jump target, since that recovery IS relative to where
    // that specific branch instruction was fetched from.
    assign ex_next_pc = ex_jump          ? ex_branch_target :
                        ex_branch_taken  ? ex_branch_target :
                                           if_pc_plus_4;

    // NOTE: because branch/jump resolution happens in EX (2 stages after
    // fetch), the instructions fetched in the meantime (while the branch
    // was still in ID/EX) are WRONG and need to be flushed. We are NOT
    // handling that yet either — this is the second bug we'll fix once we
    // get to hazard/control handling. For now, expect wrong behavior on
    // branches/jumps too, not just data hazards.

    // =========================================================
    // EX/MEM pipeline register
    // =========================================================
    wire [31:0] mem_alu_result, mem_rs2_data, mem_pc_plus_4;
    wire [4:0]  mem_rd_addr;
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg, mem_jump;

    ex_mem_reg ex_mem (
        .clk(clk), .rst(rst),
        .alu_result_in(ex_alu_result), .rs2_data_in(ex_rs2_data),
        .rd_addr_in(ex_rd_addr), .pc_plus_4_in(ex_pc_plus_4),
        .reg_write_in(ex_reg_write), .mem_read_in(ex_mem_read),
        .mem_write_in(ex_mem_write), .mem_to_reg_in(ex_mem_to_reg), .jump_in(ex_jump),

        .alu_result_out(mem_alu_result), .rs2_data_out(mem_rs2_data),
        .rd_addr_out(mem_rd_addr), .pc_plus_4_out(mem_pc_plus_4),
        .reg_write_out(mem_reg_write), .mem_read_out(mem_mem_read),
        .mem_write_out(mem_mem_write), .mem_to_reg_out(mem_mem_to_reg), .jump_out(mem_jump)
    );

    // =========================================================
    // MEM stage
    // =========================================================
    wire [31:0] mem_read_data;

    dmem dmem_inst (
        .clk(clk),
        .addr(mem_alu_result),
        .write_data(mem_rs2_data),
        .mem_read(mem_mem_read),
        .mem_write(mem_mem_write),
        .read_data(mem_read_data)
    );

    // =========================================================
    // MEM/WB pipeline register
    // =========================================================
    wire [31:0] wb_alu_result, wb_mem_read_data, wb_pc_plus_4;
    wire        wb_mem_to_reg, wb_jump;

    mem_wb_reg mem_wb (
        .clk(clk), .rst(rst),
        .alu_result_in(mem_alu_result), .mem_read_data_in(mem_read_data),
        .pc_plus_4_in(mem_pc_plus_4), .rd_addr_in(mem_rd_addr),
        .reg_write_in(mem_reg_write), .mem_to_reg_in(mem_mem_to_reg), .jump_in(mem_jump),

        .alu_result_out(wb_alu_result), .mem_read_data_out(wb_mem_read_data),
        .pc_plus_4_out(wb_pc_plus_4), .rd_addr_out(wb_rd_addr),
        .reg_write_out(wb_reg_write), .mem_to_reg_out(wb_mem_to_reg), .jump_out(wb_jump)
    );

    // =========================================================
    // WB stage
    // =========================================================
    assign wb_write_back_data = wb_mem_to_reg ? wb_mem_read_data :
                                wb_jump       ? wb_pc_plus_4 :
                                                wb_alu_result;

endmodule

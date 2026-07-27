// cpu.v
// Single-cycle RISC-V CPU: fetch, decode, execute, memory access, and
// writeback all happen within ONE clock cycle. This is the simplest
// possible correct CPU — no pipelining yet, so there's no hazard problem
// to solve either. We build this first purely to get a working, verified
// baseline before we split it into pipeline stages (which is where hazards
// and forwarding become necessary).

module cpu (
    input clk,
    input rst
);

    // --- Program Counter ---
    // The PC is a real register (state that persists across cycles), so it
    // needs its own always @(posedge clk) block, separate from everything
    // else which is largely combinational in a single-cycle design.
    reg [31:0] pc;

    // --- Fetch ---
    wire [31:0] instr;
    imem imem_inst (
        .addr(pc),
        .instr(instr)
    );

    // --- Decode ---
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [31:0] imm;
    wire [3:0]  alu_ctrl;
    wire        alu_src, reg_write, mem_read, mem_write, mem_to_reg, branch, jump;

    decoder decoder_inst (
        .instr(instr),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr), .imm(imm),
        .alu_ctrl(alu_ctrl), .alu_src(alu_src), .reg_write(reg_write),
        .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump)
    );

    // --- Register file read (decode stage) / write (writeback stage) ---
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] write_back_data; // decided further down: ALU result, memory data, or PC+4

    regfile regfile_inst (
        .clk(clk),
        .we(reg_write),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .rd_data(write_back_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    // --- Execute ---
    // alu_src picks whether the ALU's second operand is a register (R-type,
    // beq) or the decoded immediate (addi, lw, sw).
    wire [31:0] alu_operand_b = alu_src ? imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_inst (
        .a(rs1_data),
        .b(alu_operand_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // --- Memory access ---
    // Address for lw/sw comes from the ALU (rs1 + immediate offset).
    wire [31:0] mem_read_data;

    dmem dmem_inst (
        .clk(clk),
        .addr(alu_result),
        .write_data(rs2_data),   // value to store (sw)
        .mem_read(mem_read),
        .mem_write(mem_write),
        .read_data(mem_read_data)
    );

    // --- Writeback selection ---
    // rd gets one of three things depending on instruction type:
    //   - ALU result (add/sub/and/or/slt/addi)
    //   - Memory data (lw)
    //   - PC + 4 (jal, so the caller can return here later)
    wire [31:0] pc_plus_4 = pc + 32'd4;
    assign write_back_data = mem_to_reg ? mem_read_data :
                              jump      ? pc_plus_4 :
                                          alu_result;

    // --- Next PC logic ---
    // Default: PC+4 (sequential execution).
    // Branch (beq): if alu_zero (meaning rs1 == rs2, since ALU computed
    //   rs1 - rs2), take PC + immediate (branch offset) instead.
    // Jump (jal): always take PC + immediate.
    wire branch_taken = branch & alu_zero;
    wire [31:0] pc_branch_target = pc + imm;
    wire [31:0] next_pc = jump          ? pc_branch_target :
                          branch_taken  ? pc_branch_target :
                                          pc_plus_4;

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
        else
            pc <= next_pc;
    end

endmodule

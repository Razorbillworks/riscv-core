// decoder.v
// Takes a raw 32-bit instruction and produces two things:
//   1) The fields every instruction format needs (rs1, rs2, rd, immediate)
//   2) Control signals that tell the rest of the datapath what to do
//      (which ALU op, whether to write memory, whether to write regfile...)
//
// This is the module that actually "understands" the RISC-V ISA — everything
// downstream (ALU, regfile, memory) is generic and just obeys these signals.

module decoder (
    input  [31:0] instr,

    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,
    output [31:0] imm,          // sign-extended immediate, format depends on instr type

    output [3:0]  alu_ctrl,     // matches encoding used in alu.v
    output        alu_src,      // 1 = ALU's 2nd operand is immediate, 0 = register
    output        reg_write,    // 1 = this instruction writes to rd
    output        mem_read,     // 1 = load from data memory (lw)
    output        mem_write,    // 1 = store to data memory (sw)
    output        mem_to_reg,   // 1 = write-back value comes from memory, not ALU
    output        branch,       // 1 = this is a branch instruction (beq)
    output        jump          // 1 = this is a jump instruction (jal)
);

    // --- Field extraction ---
    // These bit positions are fixed by the RISC-V spec regardless of
    // instruction type, which is a deliberate design choice in RISC-V to
    // keep decode logic simple (rs1/rs2/rd sit in the same place whenever
    // they're present).
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr  = instr[11:7];

    // --- Opcode identification ---
    wire is_rtype  = (opcode == 7'b0110011); // add, sub, and, or, slt
    wire is_addi   = (opcode == 7'b0010011); // addi
    wire is_load   = (opcode == 7'b0000011); // lw
    wire is_store  = (opcode == 7'b0100011); // sw
    wire is_branch = (opcode == 7'b1100011); // beq
    wire is_jal    = (opcode == 7'b1101111); // jal

    // --- Immediate generation ---
    // Different instruction formats pack the immediate into different bit
    // positions (the ugliest part of RISC-V decode — done to keep
    // rs1/rs2/rd fixed at the cost of scrambling the immediate bits).
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    assign imm = is_store  ? imm_s :
                 is_branch ? imm_b :
                 is_jal    ? imm_j :
                             imm_i; // covers addi and lw (both I-type)

    // --- ALU control ---
    // R-type needs funct3 AND funct7 (to distinguish add vs sub, which
    // share funct3=000). Everything else just needs ADD (address calc for
    // lw/sw) or SUB (beq uses subtract + zero flag to test equality).
    reg [3:0] alu_ctrl_r;
    always @(*) begin
        if (is_rtype) begin
            case (funct3)
                3'b000: alu_ctrl_r = (funct7[5] == 1'b1) ? 4'b0001 : 4'b0000; // sub : add
                3'b111: alu_ctrl_r = 4'b0010; // and
                3'b110: alu_ctrl_r = 4'b0011; // or
                3'b010: alu_ctrl_r = 4'b0100; // slt
                default: alu_ctrl_r = 4'b0000;
            endcase
        end else if (is_branch) begin
            alu_ctrl_r = 4'b0001; // subtract, then check zero flag for equality
        end else begin
            alu_ctrl_r = 4'b0000; // addi, lw, sw all just need addition
        end
    end
    assign alu_ctrl = alu_ctrl_r;

    // --- Remaining control signals ---
    assign alu_src    = !is_rtype && !is_branch; // imm operand, except R-type/branch which use two registers
    assign reg_write  = is_rtype || is_addi || is_load || is_jal; // jal writes return address into rd
    assign mem_read   = is_load;
    assign mem_write  = is_store;
    assign mem_to_reg = is_load;
    assign branch     = is_branch;
    assign jump       = is_jal;

endmodule

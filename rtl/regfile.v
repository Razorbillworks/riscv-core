// regfile.v
// RISC-V has 32 general-purpose registers (x0-x31), each 32 bits.
// x0 is hardwired to zero — writes to it are ignored, reads always return 0.
//
// Every instruction can read up to 2 registers (rs1, rs2) and write at most 1
// (rd) per cycle, so we need 2 read ports and 1 write port.

module regfile (
    input         clk,
    input         we,          // write enable
    input  [4:0]  rs1_addr,    // source register 1 (5 bits -> 32 registers)
    input  [4:0]  rs2_addr,    // source register 2
    input  [4:0]  rd_addr,     // destination register to write
    input  [31:0] rd_data,     // data to write into rd_addr
    output [31:0] rs1_data,    // value read from rs1
    output [31:0] rs2_data     // value read from rs2
);

    // The actual storage: 32 registers, 32 bits each.
    reg [31:0] regs [0:31];

    // Real hardware powers up in an undefined state, but for simulation
    // sanity (and because we don't have a real reset signal wired into the
    // regfile in this simple design) we zero everything at time 0.
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    // --- Reads are combinational, with a same-cycle write bypass ---
    // Without this bypass: if an instruction writes register X on the same
    // clock edge that a later instruction is reading X (which happens
    // routinely in a pipeline — e.g. an instruction's WB stage lands on
    // the exact same cycle as a different instruction's ID stage), the
    // write is non-blocking (<=) and hasn't actually landed in regs[]
    // yet at the moment the read is evaluated, so the read would return
    // the OLD, stale value. Real register files commonly solve this with
    // exactly this kind of "write-first" internal bypass, since making
    // every instruction wait an extra cycle just for this case would be
    // wasteful when we can just forward the write data directly.
    // x0 stays hardwired to 0 regardless.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 :
                       (we && rd_addr == rs1_addr) ? rd_data :
                                                      regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 :
                       (we && rd_addr == rs2_addr) ? rd_data :
                                                      regs[rs2_addr];

    // --- Writes are clocked (sequential logic) ---
    // always @(posedge clk) means: run this block once, at the instant the
    // clock signal rises from 0 to 1. This is what makes it a real hardware
    // register (flip-flop-backed storage) instead of combinational logic —
    // the value written here PERSISTS across cycles until written again.
    always @(posedge clk) begin
        if (we && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

    // Note on <= vs = :
    // <= is a "non-blocking assignment", used for sequential (clocked) logic.
    // It means "schedule this update to happen, but don't let it affect other
    // reads within the same clock edge" — this correctly models how real
    // flip-flops update simultaneously. Combinational logic (like the ALU's
    // always @(*) block) uses blocking assignment (=) instead. Mixing these
    // up is one of the most common beginner Verilog bugs.

endmodule

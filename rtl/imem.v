// imem.v
// Instruction memory: holds the program. Read-only from the CPU's
// perspective in this simple design (no self-modifying code).
//
// Address is byte-addressed (like real RISC-V), but instructions are
// always 4 bytes, so we drop the low 2 bits when indexing into our array.

module imem (
    input  [31:0] addr,       // PC value
    output [31:0] instr       // instruction word at that address
);

    // 256 words = 1KB of instruction memory, plenty for small test programs.
    reg [31:0] mem [0:255];

    // $readmemh loads mem[] from a hex text file at simulation start —
    // this is how we'll load our test programs without hardcoding them here.
    initial begin
        $readmemh("program.hex", mem);
    end

    // addr[31:2] : drop bottom 2 bits since instructions are word-aligned
    // (every address is a multiple of 4, so those 2 bits are always 0 anyway)
    assign instr = mem[addr[31:2]];

endmodule

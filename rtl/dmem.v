// dmem.v
// Data memory: used only by lw (read) and sw (write). Separate from
// instruction memory (imem) — this is a "Harvard-ish" split for simplicity,
// even though real RISC-V systems usually use a unified memory space.

module dmem (
    input         clk,
    input  [31:0] addr,
    input  [31:0] write_data,
    input         mem_read,
    input         mem_write,
    output [31:0] read_data
);

    reg [31:0] mem [0:255]; // 1KB data memory

    // Read is combinational (like the regfile) so the value is available
    // within the same cycle for a single-cycle design.
    assign read_data = mem_read ? mem[addr[31:2]] : 32'd0;

    // Write is clocked — actually commits on the rising edge.
    always @(posedge clk) begin
        if (mem_write) begin
            mem[addr[31:2]] <= write_data;
        end
    end

endmodule

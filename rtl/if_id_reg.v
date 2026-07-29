// if_id_reg.v
// Pipeline register between Fetch and Decode stages.
//
// Why this exists: in the single-cycle CPU, "fetch an instruction" and
// "decode it" happened in the same instant, same cycle. In a pipeline, we
// want the Fetch stage to grab instruction N while the Decode stage is
// still working on instruction N-1 (the one fetched last cycle). This
// register is what "remembers" instruction N-1's data so Decode can use it
// on the next clock edge, even though Fetch has already moved on.
//
// Every pipeline register in this design follows the same shape:
//   - on each clock edge, latch (save) all inputs into matching outputs
//   - optionally support "flush" (clear to a bubble/NOP) and "stall" (hold
//     current value, don't accept new input) — added once we deal with
//     hazards. For now: just plain pass-through latching.

module if_id_reg (
    input         clk,
    input         rst,
    input  [31:0] pc_in,
    input  [31:0] instr_in,

    output reg [31:0] pc_out,
    output reg [31:0] instr_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out    <= 32'd0;
            instr_out <= 32'd0; // all-zero instruction matches none of our
                                 // decoder's opcodes, so every control signal
                                 // comes out 0 -> this already behaves as a
                                 // safe "do nothing" bubble
        end else begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
    end

endmodule

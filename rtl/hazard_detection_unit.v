// hazard_detection_unit.v
// Detects the ONE hazard forwarding cannot fix: load-use.
//
//   lw  x1, 0(x2)
//   add x3, x1, x4      <- needs x1 the very next instruction
//
// When "add" is in ID (being decoded), "lw" is in EX (id_ex register holds
// its info). "lw"'s result isn't ready until MEM completes — forwarding
// from EX/MEM would grab garbage a cycle too early. The only correct fix
// is to stall: freeze PC and IF/ID for one cycle, and insert a bubble into
// ID/EX so EX does nothing useful that cycle. This gives "lw" time to reach
// MEM, so by the NEXT cycle, ordinary EX/MEM forwarding can supply the
// value normally.

module hazard_detection_unit (
    // The load currently sitting in ID/EX (i.e. one stage ahead of the
    // instruction we're currently decoding in ID)
    input        ex_mem_read,   // is the EX-stage instruction a load?
    input [4:0]  ex_rd_addr,    // its destination register

    // The instruction currently being decoded in ID
    input [4:0]  id_rs1_addr,
    input [4:0]  id_rs2_addr,

    output       stall
);

    // Stall if EX is a load AND its destination matches either source
    // register the instruction in ID needs (and it's not x0, which never
    // creates a real hazard).
    assign stall = ex_mem_read && (ex_rd_addr != 5'd0) &&
                   ((ex_rd_addr == id_rs1_addr) || (ex_rd_addr == id_rs2_addr));

endmodule

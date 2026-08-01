// btb.v
// Branch Target Buffer: a small cache mapping "PC of a branch/jump" ->
// "where it went last time". This is what lets us guess a TARGET address
// at fetch time, before we've even decoded the instruction (let alone
// computed rs1+imm in EX). Without a BTB, gshare's taken/not-taken
// prediction is useless for actually saving cycles — knowing "yes, taken"
// doesn't help if we don't also know "taken... to where?".
//
// Each entry stores: valid bit, the PC that produced this entry (a "tag",
// so we don't act on a stale/mismatched entry that happens to alias to
// the same table index), and the target address last observed.

module btb #(
    parameter INDEX_BITS = 6,
    parameter TABLE_SIZE = (1 << INDEX_BITS)
) (
    input                      clk,
    input                      rst,

    // --- Lookup (combinational, done at IF stage) ---
    input      [31:0]          fetch_pc,
    output                     btb_hit,       // 1 = we have a cached target for this PC
    output     [31:0]          predicted_target,

    // --- Update (done at EX stage, once a branch/jump resolves) ---
    input                      update_valid,  // 1 = a branch/jump resolved this cycle
    input      [31:0]          update_pc,
    input      [31:0]          update_target,
    input                      update_taken   // only cache a target if it was actually taken —
                                               // no point caching a target for a branch that
                                               // didn't jump anywhere
);

    reg                  valid [0:TABLE_SIZE-1];
    reg [31:0]            tag   [0:TABLE_SIZE-1]; // stores the full PC, for mismatch detection
    reg [31:0]            target[0:TABLE_SIZE-1];

    integer i;
    initial begin
        for (i = 0; i < TABLE_SIZE; i = i + 1)
            valid[i] = 1'b0;
    end

    // --- Lookup ---
    wire [INDEX_BITS-1:0] lookup_index = fetch_pc[INDEX_BITS+1:2];
    assign btb_hit = valid[lookup_index] && (tag[lookup_index] == fetch_pc);
    assign predicted_target = target[lookup_index];

    // --- Update ---
    wire [INDEX_BITS-1:0] update_index = update_pc[INDEX_BITS+1:2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < TABLE_SIZE; i = i + 1)
                valid[i] <= 1'b0;
        end else if (update_valid && update_taken) begin
            valid[update_index]  <= 1'b1;
            tag[update_index]    <= update_pc;
            target[update_index] <= update_target;
        end
        // Note: we deliberately do NOT invalidate an entry just because a
        // branch was NOT taken this time around — a branch can legitimately
        // be taken most of the time and occasionally fall through (like our
        // loop-exit case), so keeping the cached target around for next
        // time is usually still useful. gshare's own taken/not-taken
        // prediction is what decides whether we ACT on this cached target,
        // not the BTB itself.
    end

endmodule

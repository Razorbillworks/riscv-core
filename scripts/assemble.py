#!/usr/bin/env python3
# assemble.py
# Tiny hand-written encoder for our 10-instruction subset — not a general
# assembler, just enough to generate test programs for the CPU without
# hand-computing binary encodings by hand every time.

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def i_type(imm, rs1, funct3, rd, opcode):
    imm = imm & 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def s_type(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0xFFF
    imm_hi = (imm >> 5) & 0x7F
    imm_lo = imm & 0x1F
    return (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_lo << 7) | opcode

def b_type(imm, rs2, rs1, funct3, opcode):
    # imm is a byte offset, must be even (word/half-aligned branch target)
    imm = imm & 0x1FFF
    bit12 = (imm >> 12) & 1
    bit11 = (imm >> 11) & 1
    bits10_5 = (imm >> 5) & 0x3F
    bits4_1 = (imm >> 1) & 0xF
    return (bit12 << 31) | (bits10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (bits4_1 << 8) | (bit11 << 7) | opcode

def j_type(imm, rd, opcode):
    imm = imm & 0x1FFFFF
    bit20 = (imm >> 20) & 1
    bits10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 1
    bits19_12 = (imm >> 12) & 0xFF
    return (bit20 << 31) | (bits10_1 << 21) | (bit11 << 20) | (bits19_12 << 12) | (rd << 7) | opcode

def add(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b000, rd, 0b0110011)
def sub(rd, rs1, rs2):  return r_type(0b0100000, rs2, rs1, 0b000, rd, 0b0110011)
def and_(rd, rs1, rs2): return r_type(0b0000000, rs2, rs1, 0b111, rd, 0b0110011)
def or_(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b110, rd, 0b0110011)
def slt(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b010, rd, 0b0110011)
def addi(rd, rs1, imm): return i_type(imm, rs1, 0b000, rd, 0b0010011)
def lw(rd, rs1, imm):   return i_type(imm, rs1, 0b010, rd, 0b0000011)
def sw(rs2, rs1, imm):  return s_type(imm, rs2, rs1, 0b010, 0b0100011)
def beq(rs1, rs2, imm): return b_type(imm, rs2, rs1, 0b000, 0b1100011)
def jal(rd, imm):       return j_type(imm, rd, 0b1101111)

if __name__ == "__main__":
    import sys

    # ORIGINAL test program (kept for regression against single-cycle CPU).
    program = [
        addi(1, 0, 5),
        addi(2, 0, 3),
        add(3, 1, 2),
        sub(4, 1, 2),
        sw(3, 0, 0),
        lw(5, 0, 0),
        beq(1, 1, 8),
        addi(6, 0, 99),
        addi(7, 0, 7),
        and_(8, 1, 2),
        or_(9, 1, 2),
        slt(10, 2, 1),
    ]

    # HAZARD-EXPOSING test program: back-to-back dependent instructions,
    # deliberately no spacing, to genuinely trigger the data hazard bug in
    # the pipelined CPU (rather than accidentally working due to spacing).
    #
    # x1 = 10
    # x2 = x1 + x1        <- depends on x1, IMMEDIATELY after it's set
    # x3 = x2 + x2        <- depends on x2, IMMEDIATELY after it's set
    # x4 = x3 + x3        <- depends on x3, IMMEDIATELY after it's set
    # Expected (correct): x1=10, x2=20, x3=40, x4=80
    hazard_program = [
        addi(1, 0, 10),
        add(2, 1, 1),   # x2 = x1 + x1
        add(3, 2, 2),   # x3 = x2 + x2
        add(4, 3, 3),   # x4 = x3 + x3
    ]

    # LOAD-USE hazard test: a load immediately followed by a dependent
    # instruction. Forwarding alone cannot fix this (data isn't ready
    # until MEM completes) — this specifically tests the stall logic.
    #
    # x1 = 99
    # sw x1, 0(x0)        ; mem[0] = 99
    # lw x2, 0(x0)        ; x2 = 99 (load)
    # add x3, x2, x2       ; x3 = 198 -- immediately depends on x2, the load
    # Expected (correct): x1=99, x2=99, x3=198
    loaduse_program = [
        addi(1, 0, 99),
        sw(1, 0, 0),
        lw(2, 0, 0),
        add(3, 2, 2),   # immediately depends on lw's result
    ]

    # LOOP program: demonstrates branch prediction actually paying off.
    # A real loop, executed multiple times, so the SAME branch is resolved
    # repeatedly — letting BTB/gshare learn the pattern and predict
    # correctly on later iterations (only mispredicting on the very first
    # encounter, and on the final loop-exit transition).
    #
    #   x1 = 0        (counter)
    #   x2 = 5        (loop limit)
    # loop:              (address 0x08)
    #   addi x1, x1, 1      ; x1++
    #   slt  x3, x1, x2     ; x3 = (x1 < x2) ? 1 : 0
    #   beq  x3, x0, exit   ; if x3==0 (x1>=x2), exit loop (0x10 -> 0x18, offset=8)
    #   beq  x0, x0, loop   ; jump back to loop start (0x14 -> 0x08, offset=-12)
    # exit:               (address 0x18)
    #   addi x4, x0, 42     ; marker: loop finished correctly
    loop_program = [
        addi(1, 0, 0),      # 0x00: x1 = 0
        addi(2, 0, 5),      # 0x04: x2 = 5
        addi(1, 1, 1),      # 0x08: loop: x1 = x1 + 1
        slt(3, 1, 2),       # 0x0C: x3 = (x1 < x2)
        beq(3, 0, 8),       # 0x10: if x3==0, branch to exit (0x18)
        beq(0, 0, -12),     # 0x14: jump back to loop (0x08)
        addi(4, 0, 42),     # 0x18: exit: marker
    ]

    which = sys.argv[2] if len(sys.argv) > 2 else "original"
    if which == "hazard":
        program_to_use = hazard_program
    elif which == "loaduse":
        program_to_use = loaduse_program
    elif which == "loop":
        program_to_use = loop_program
    else:
        program_to_use = program

    out_path = sys.argv[1] if len(sys.argv) > 1 else "program.hex"
    with open(out_path, "w") as f:
        for instr in program_to_use:
            f.write(f"{instr:08x}\n")
        for _ in range(256 - len(program_to_use)):
            f.write("00000013\n")  # addi x0, x0, 0 = NOP

    print(f"Wrote {len(program_to_use)} instructions to {out_path} (variant: {which})")

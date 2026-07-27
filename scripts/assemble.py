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

    # Test program (addresses shown for reference, each instr = 4 bytes):
    # 0x00: addi x1, x0, 5      ; x1 = 5
    # 0x04: addi x2, x0, 3      ; x2 = 3
    # 0x08: add  x3, x1, x2     ; x3 = 8
    # 0x0C: sub  x4, x1, x2     ; x4 = 2
    # 0x10: sw   x3, 0(x0)      ; mem[0] = 8
    # 0x14: lw   x5, 0(x0)      ; x5 = 8
    # 0x18: beq  x1, x1, 8      ; always taken (x1==x1), skip next instr -> pc becomes 0x24
    # 0x1C: addi x6, x0, 99     ; SKIPPED (should never execute)
    # 0x20: addi x6, x0, 99     ; SKIPPED (padding, branch target math below accounts for this)
    # 0x24: addi x7, x0, 7      ; x7 = 7  <- branch lands here
    # 0x28: and  x8, x1, x2     ; x8 = 5 & 3 = 1
    # 0x2C: or   x9, x1, x2     ; x9 = 5 | 3 = 7
    # 0x30: slt  x10, x2, x1    ; x10 = (3 < 5) = 1

    program = [
        addi(1, 0, 5),
        addi(2, 0, 3),
        add(3, 1, 2),
        sub(4, 1, 2),
        sw(3, 0, 0),
        lw(5, 0, 0),
        beq(1, 1, 8),       # if taken, pc = 0x18 + 8 = 0x20 -> skips ONE instruction (the addi at 0x1C)
        addi(6, 0, 99),     # should be skipped
        addi(7, 0, 7),      # branch target lands here (0x20)
        and_(8, 1, 2),
        or_(9, 1, 2),
        slt(10, 2, 1),
    ]

    out_path = sys.argv[1] if len(sys.argv) > 1 else "program.hex"
    with open(out_path, "w") as f:
        for instr in program:
            f.write(f"{instr:08x}\n")
        # pad remaining memory with NOPs (addi x0,x0,0) so imem doesn't read garbage
        for _ in range(256 - len(program)):
            f.write("00000013\n")  # addi x0, x0, 0 = NOP

    print(f"Wrote {len(program)} instructions to {out_path}")

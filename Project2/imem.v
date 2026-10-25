`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module imem (
    input  wire [7:0]  addr,
    output reg  [15:0] instr
);

    always @(*) begin
        case (addr)
            8'h00: instr = 16'h823C; // LDI  R1, 0x3C
            8'h01: instr = 16'h840F; // LDI  R2, 0x0F
            8'h02: instr = 16'h3650; // AND  R3, R1, R2
            8'h03: instr = 16'h4850; // OR   R4, R1, R2
            8'h04: instr = 16'h5A50; // XOR  R5, R1, R2
            8'h05: instr = 16'h6D40; // SHL  R6, R5
            8'h06: instr = 16'h7EC0; // SHR  R7, R3
            8'h07: instr = 16'h2FF8; // SUB  R7, R7, R7
            8'h08: instr = 16'hD00A; // BZ   0x0A
            8'h09: instr = 16'h8EFF; // LDI  R7, 0xFF (flushed)
            8'h0A: instr = 16'h8205; // LDI  R1, 0x05
            8'h0B: instr = 16'h8400; // LDI  R2, 0x00
            8'h0C: instr = 16'h8601; // LDI  R3, 0x01
            8'h0D: instr = 16'h1488; // ADD  R2, R2, R1
            8'h0E: instr = 16'h2258; // SUB  R1, R1, R3
            8'h0F: instr = 16'hE00D; // BNZ  0x0D
            8'h10: instr = 16'h8820; // LDI  R4, 0x20
            8'h11: instr = 16'hB500; // ST   R2, [R4]
            8'h12: instr = 16'hAB00; // LD   R5, [R4]
            8'h13: instr = 16'h9AF0; // ADDI R5, 0xF0
            8'h14: instr = 16'h9A01; // ADDI R5, 0x01
            8'h15: instr = 16'hC017; // JMP  0x17
            8'h16: instr = 16'h8EFF; // LDI  R7, 0xFF (flushed)
            8'h17: instr = 16'hF000; // HLT
            default: instr = 16'h0000; // NOP
        endcase
    end

endmodule
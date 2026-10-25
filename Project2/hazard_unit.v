`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module hazard_unit (
    input  wire       ifid_valid,
    input  wire [2:0] id_ra,
    input  wire [2:0] id_rb,
    input  wire       id_uses_a,
    input  wire       id_uses_b,

    input  wire       idex_valid,
    input  wire [2:0] idex_ra,
    input  wire [2:0] idex_rb,
    input  wire       idex_uses_a,
    input  wire       idex_uses_b,
    input  wire       idex_mem_to_reg,
    input  wire [2:0] idex_rd,

    input  wire       exmem_valid,
    input  wire       exmem_reg_we,
    input  wire       exmem_mem_to_reg,
    input  wire [2:0] exmem_rd,

    input  wire       memwb_valid,
    input  wire       memwb_reg_we,
    input  wire [2:0] memwb_rd,

    output reg  [1:0] fwd_a_sel,
    output reg  [1:0] fwd_b_sel,
    output wire       stall
);

    always @(*) begin
        if (idex_valid && idex_uses_a &&
            exmem_valid && exmem_reg_we && !exmem_mem_to_reg &&
            (exmem_rd == idex_ra)) begin
            fwd_a_sel = 2'b01;
        end else if (idex_valid && idex_uses_a &&
                     memwb_valid && memwb_reg_we &&
                     (memwb_rd == idex_ra)) begin
            fwd_a_sel = 2'b10;
        end else begin
            fwd_a_sel = 2'b00;
        end
    end

    always @(*) begin
        if (idex_valid && idex_uses_b &&
            exmem_valid && exmem_reg_we && !exmem_mem_to_reg &&
            (exmem_rd == idex_rb)) begin
            fwd_b_sel = 2'b01;
        end else if (idex_valid && idex_uses_b &&
                     memwb_valid && memwb_reg_we &&
                     (memwb_rd == idex_rb)) begin
            fwd_b_sel = 2'b10;
        end else begin
            fwd_b_sel = 2'b00;
        end
    end

    assign stall = ifid_valid && idex_valid && idex_mem_to_reg &&
                   ((id_uses_a && (id_ra == idex_rd)) ||
                    (id_uses_b && (id_rb == idex_rd)));

endmodule
`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module regfile (
    input  wire       clk,
    input  wire       rst,
    input  wire       we,
    input  wire [2:0] waddr,
    input  wire [7:0] wdata,
    input  wire [2:0] raddr_a,
    output wire [7:0] rdata_a,
    input  wire [2:0] raddr_b,
    output wire [7:0] rdata_b
);

    reg [7:0] regs [0:7];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) begin
                regs[i] <= 8'h00;
            end
        end else if (we) begin
            regs[waddr] <= wdata;
        end
    end

    // Write-through bypass (WB -> ID in same cycle)
    assign rdata_a = (we && (waddr == raddr_a)) ? wdata : regs[raddr_a];
    assign rdata_b = (we && (waddr == raddr_b)) ? wdata : regs[raddr_b];

endmodule
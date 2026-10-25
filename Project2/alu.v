`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] alu_op,
    output reg  [7:0] result,
    output wire       z,
    output reg        c
);

    wire [8:0] add_full = {1'b0, a} + {1'b0, b};
    wire [8:0] sub_full = {1'b0, a} - {1'b0, b};

    always @(*) begin
        result = 8'h00;
        c      = 1'b0;
        case (alu_op)
            3'd0: begin // ADD
                result = add_full[7:0];
                c      = add_full[8];
            end
            3'd1: begin // SUB (c = borrow when a < b)
                result = sub_full[7:0];
                c      = sub_full[8];
            end
            3'd2: begin // AND
                result = a & b;
                c      = 1'b0;
            end
            3'd3: begin // OR
                result = a | b;
                c      = 1'b0;
            end
            3'd4: begin // XOR
                result = a ^ b;
                c      = 1'b0;
            end
            3'd5: begin // SHL
                result = {a[6:0], 1'b0};
                c      = a[7];
            end
            3'd6: begin // SHR
                result = {1'b0, a[7:1]};
                c      = a[0];
            end
            3'd7: begin // PASS B (LDI)
                result = b;
                c      = 1'b0;
            end
            default: begin
                result = 8'h00;
                c      = 1'b0;
            end
        endcase
    end

    assign z = (result == 8'h00);

endmodule
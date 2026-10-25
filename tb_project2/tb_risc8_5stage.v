`timescale 1ns / 1ps

module tb_risc8_5stage;

    reg        clk;
    reg        rst;
    wire       halted;
    wire [7:0] pc_out;
    wire [1:0] flags_out;
    wire       instr_done;

    risc8_5stage_core dut (
        .clk        (clk),
        .rst        (rst),
        .halted     (halted),
        .pc_out     (pc_out),
        .flags_out  (flags_out),
        .instr_done (instr_done)
    );

    // 100 MHz clock (10 ns period, posedge at 5, 15, 25, ..., 525 ns)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    integer cycle_count;
    integer instr_count;
    integer stall_count;
    integer branch_count;
    integer fwd_count;
    integer errors;

    initial begin
        rst          = 1'b1;
        cycle_count  = 0;
        instr_count  = 0;
        stall_count  = 0;
        branch_count = 0;
        fwd_count    = 0;
        errors       = 0;

        // Giữ reset qua 2 sườn lên (5 ns và 15 ns), nhả reset ở 20 ns
        #20 rst = 1'b0;

        $display("================================================================================");
        $display(" Cycle | PC   | IF/ID | ID/EX | EX/MEM | MEM/WB | Stall | Branch | FwdA | FwdB ");
        $display("================================================================================");

        // Lấy mẫu trực tiếp tại mỗi sườn lên từ Cycle 1 (25 ns) đến Cycle 51 (525 ns)
        while (!halted && cycle_count < 200) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (instr_done)
                instr_count = instr_count + 1;
            if (dut.stall)
                stall_count = stall_count + 1;
            if (dut.take_branch)
                branch_count = branch_count + 1;
            if (dut.fwd_a_sel != 2'b00)
                fwd_count = fwd_count + 1;
            if (dut.fwd_b_sel != 2'b00)
                fwd_count = fwd_count + 1;

            $display("  %2d   | 0x%02h |   %b   |   %b   |   %b    |   %b    |   %b   |   %b    |  %b  |  %b  ",
                     cycle_count, pc_out, dut.ifid_valid, dut.idex_valid,
                     dut.exmem_valid, dut.memwb_valid, dut.stall,
                     dut.take_branch, dut.fwd_a_sel, dut.fwd_b_sel);
        end

        // Đợi thêm 20 ns sau chu kỳ 51 (525 ns + 20 ns = 545 ns)
        #20;

        $display("================================================================================");
        $display("Cycles / instructions : %0d / %0d (CPI = %0.2f)",
                 cycle_count, instr_count, $itor(cycle_count) / $itor(instr_count));
        $display("Load-use stalls       : %0d", stall_count);
        $display("Taken branches        : %0d", branch_count);
        $display("Forwarded operands    : %0d", fwd_count);
        $display("--------------------------------------------------------------------------------");

        if (dut.u_regfile.regs[1] !== 8'h00) begin
            $display("FAIL: R1 = 0x%02h (expected 0x00)", dut.u_regfile.regs[1]);
            errors = errors + 1;
        end else $display("PASS: R1 = 0x%02h", dut.u_regfile.regs[1]);

        if (dut.u_regfile.regs[2] !== 8'h0F) begin
            $display("FAIL: R2 = 0x%02h (expected 0x0F)", dut.u_regfile.regs[2]);
            errors = errors + 1;
        end else $display("PASS: R2 = 0x%02h", dut.u_regfile.regs[2]);

        if (dut.u_regfile.regs[3] !== 8'h01) begin
            $display("FAIL: R3 = 0x%02h (expected 0x01)", dut.u_regfile.regs[3]);
            errors = errors + 1;
        end else $display("PASS: R3 = 0x%02h", dut.u_regfile.regs[3]);

        if (dut.u_regfile.regs[4] !== 8'h20) begin
            $display("FAIL: R4 = 0x%02h (expected 0x20)", dut.u_regfile.regs[4]);
            errors = errors + 1;
        end else $display("PASS: R4 = 0x%02h", dut.u_regfile.regs[4]);

        if (dut.u_regfile.regs[5] !== 8'h00) begin
            $display("FAIL: R5 = 0x%02h (expected 0x00)", dut.u_regfile.regs[5]);
            errors = errors + 1;
        end else $display("PASS: R5 = 0x%02h", dut.u_regfile.regs[5]);

        if (dut.u_regfile.regs[6] !== 8'h66) begin
            $display("FAIL: R6 = 0x%02h (expected 0x66)", dut.u_regfile.regs[6]);
            errors = errors + 1;
        end else $display("PASS: R6 = 0x%02h", dut.u_regfile.regs[6]);

        if (dut.u_regfile.regs[7] !== 8'h00) begin
            $display("FAIL: R7 = 0x%02h (expected 0x00)", dut.u_regfile.regs[7]);
            errors = errors + 1;
        end else $display("PASS: R7 = 0x%02h", dut.u_regfile.regs[7]);

        if (dut.u_dmem.mem[8'h20] !== 8'h0F) begin
            $display("FAIL: Memory[0x20] = 0x%02h (expected 0x0F)", dut.u_dmem.mem[8'h20]);
            errors = errors + 1;
        end else $display("PASS: Memory[0x20] = 0x%02h", dut.u_dmem.mem[8'h20]);

        if (flags_out !== 2'b11) begin
            $display("FAIL: Flags {Z, C} = %b, %b (expected 1, 1)", flags_out[1], flags_out[0]);
            errors = errors + 1;
        end else $display("PASS: Flags Z = %b, C = %b", flags_out[1], flags_out[0]);

        $display("================================================================================");
        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** TEST FAILED WITH %0d ERROR(S) ***", errors);
        $display("================================================================================");

        $finish;
    end

endmodule
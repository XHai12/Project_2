`timescale 1ns / 1ps

module risc8_5stage_core (
    input  wire       clk,
    input  wire       rst,
    output wire       halted,
    output wire [7:0] pc_out,
    output wire [1:0] flags_out,
    output wire       instr_done
);

    // =========================================================================
    // Program Counter & Architectural Flags
    // =========================================================================
    reg [7:0] pc;
    reg       flag_z;
    reg       flag_c;

    // =========================================================================
    // Pipeline Register 1: IF/ID (17 bits)
    // =========================================================================
    reg        ifid_valid;
    reg [15:0] ifid_instr;

    // =========================================================================
    // Pipeline Register 2: ID/EX (48 bits)
    // =========================================================================
    reg        idex_valid;
    reg [2:0]  idex_alu_op;
    reg        idex_alu_src_imm;
    reg        idex_uses_a;
    reg        idex_uses_b;
    reg        idex_reg_we;
    reg        idex_mem_to_reg;
    reg        idex_mem_we;
    reg        idex_flag_we;
    reg        idex_jump;
    reg        idex_br_z;
    reg        idex_br_nz;
    reg        idex_halt;
    reg [2:0]  idex_rd;
    reg [2:0]  idex_ra;
    reg [2:0]  idex_rb;
    reg [7:0]  idex_rdata_a;
    reg [7:0]  idex_rdata_b;
    reg [7:0]  idex_imm8;

    // =========================================================================
    // Pipeline Register 3: EX/MEM (32 bits)
    // =========================================================================
    reg        exmem_valid;
    reg        exmem_reg_we;
    reg        exmem_mem_to_reg;
    reg        exmem_mem_we;
    reg        exmem_halt;
    reg [2:0]  exmem_rd;
    reg [7:0]  exmem_alu_result;
    reg [7:0]  exmem_addr;
    reg [7:0]  exmem_store_data;

    // =========================================================================
    // Pipeline Register 4: MEM/WB (14 bits)
    // =========================================================================
    reg        memwb_valid;
    reg        memwb_reg_we;
    reg        memwb_halt;
    reg [2:0]  memwb_rd;
    reg [7:0]  memwb_result;

    // =========================================================================
    // Stage 1: Instruction Fetch (IF)
    // =========================================================================
    wire [15:0] imem_instr;

    imem u_imem (
        .addr  (pc),
        .instr (imem_instr)
    );

    // =========================================================================
    // Stage 2: Instruction Decode (ID)
    // =========================================================================
    wire [3:0] id_opcode = ifid_instr[15:12];
    wire [2:0] id_rd     = ifid_instr[11:9];
    wire [2:0] id_rs1    = ifid_instr[8:6];
    wire [2:0] id_rs2    = ifid_instr[5:3];
    wire [7:0] id_imm8   = ifid_instr[7:0];

    wire [2:0] id_alu_op;
    wire       id_alu_src_imm;
    wire       id_ra_is_rd;
    wire       id_rb_is_rd;
    wire       id_uses_a;
    wire       id_uses_b;
    wire       id_reg_we;
    wire       id_mem_to_reg;
    wire       id_mem_we;
    wire       id_flag_we;
    wire       id_jump;
    wire       id_br_z;
    wire       id_br_nz;
    wire       id_halt;

    control_unit u_ctrl (
        .opcode      (id_opcode),
        .alu_op      (id_alu_op),
        .alu_src_imm (id_alu_src_imm),
        .ra_is_rd    (id_ra_is_rd),
        .rb_is_rd    (id_rb_is_rd),
        .uses_a      (id_uses_a),
        .uses_b      (id_uses_b),
        .reg_we      (id_reg_we),
        .mem_to_reg  (id_mem_to_reg),
        .mem_we      (id_mem_we),
        .flag_we     (id_flag_we),
        .jump        (id_jump),
        .br_z        (id_br_z),
        .br_nz       (id_br_nz),
        .halt        (id_halt)
    );

    wire [2:0] id_ra = id_ra_is_rd ? id_rd : id_rs1;
    wire [2:0] id_rb = id_rb_is_rd ? id_rd : id_rs2;

    wire [7:0] id_rdata_a;
    wire [7:0] id_rdata_b;

    wire       wb_we     = memwb_valid && memwb_reg_we && !halted;
    wire [2:0] wb_waddr  = memwb_rd;
    wire [7:0] wb_wdata  = memwb_result;

    regfile u_regfile (
        .clk     (clk),
        .rst     (rst),
        .we      (wb_we),
        .waddr   (wb_waddr),
        .wdata   (wb_wdata),
        .raddr_a (id_ra),
        .rdata_a (id_rdata_a),
        .raddr_b (id_rb),
        .rdata_b (id_rdata_b)
    );

    // =========================================================================
    // Hazard Unit
    // =========================================================================
    wire [1:0] fwd_a_sel;
    wire [1:0] fwd_b_sel;
    wire       stall;

    hazard_unit u_hazard (
        .ifid_valid       (ifid_valid),
        .id_ra            (id_ra),
        .id_rb            (id_rb),
        .id_uses_a        (id_uses_a),
        .id_uses_b        (id_uses_b),
        .idex_valid       (idex_valid),
        .idex_ra          (idex_ra),
        .idex_rb          (idex_rb),
        .idex_uses_a      (idex_uses_a),
        .idex_uses_b      (idex_uses_b),
        .idex_mem_to_reg  (idex_mem_to_reg),
        .idex_rd          (idex_rd),
        .exmem_valid      (exmem_valid),
        .exmem_reg_we     (exmem_reg_we),
        .exmem_mem_to_reg (exmem_mem_to_reg),
        .exmem_rd         (exmem_rd),
        .memwb_valid      (memwb_valid),
        .memwb_reg_we     (memwb_reg_we),
        .memwb_rd         (memwb_rd),
        .fwd_a_sel        (fwd_a_sel),
        .fwd_b_sel        (fwd_b_sel),
        .stall            (stall)
    );

    // =========================================================================
    // Stage 3: Execute (EX)
    // =========================================================================
    wire [7:0] ex_opa = (fwd_a_sel == 2'b01) ? exmem_alu_result :
                        (fwd_a_sel == 2'b10) ? memwb_result     : idex_rdata_a;

    wire [7:0] ex_opb = (fwd_b_sel == 2'b01) ? exmem_alu_result :
                        (fwd_b_sel == 2'b10) ? memwb_result     : idex_rdata_b;

    wire [7:0] alu_b  = idex_alu_src_imm ? idex_imm8 : ex_opb;

    wire [7:0] alu_result;
    wire       alu_z;
    wire       alu_c;

    alu u_alu (
        .a      (ex_opa),
        .b      (alu_b),
        .alu_op (idex_alu_op),
        .result (alu_result),
        .z      (alu_z),
        .c      (alu_c)
    );

    wire take_branch = idex_valid &&
                       (idex_jump || (idex_br_z && flag_z) || (idex_br_nz && !flag_z));

    wire halt_in_ex_or_later = (idex_valid  && idex_halt)  ||
                               (exmem_valid && exmem_halt) ||
                               (memwb_valid && memwb_halt);

    // =========================================================================
    // Stage 4: Memory Access (MEM)
    // =========================================================================
    wire [7:0] dmem_rdata;

    dmem u_dmem (
        .clk   (clk),
        .we    (exmem_valid && exmem_mem_we && !halted),
        .addr  (exmem_addr),
        .wdata (exmem_store_data),
        .rdata (dmem_rdata)
    );

    wire [7:0] mem_result = exmem_mem_to_reg ? dmem_rdata : exmem_alu_result;

    // =========================================================================
    // Sequential Pipeline State Transitions
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            pc               <= 8'h00;
            flag_z           <= 1'b0;
            flag_c           <= 1'b0;

            ifid_valid       <= 1'b0;
            ifid_instr       <= 16'h0000;

            idex_valid       <= 1'b0;
            idex_alu_op      <= 3'd0;
            idex_alu_src_imm <= 1'b0;
            idex_uses_a      <= 1'b0;
            idex_uses_b      <= 1'b0;
            idex_reg_we      <= 1'b0;
            idex_mem_to_reg  <= 1'b0;
            idex_mem_we      <= 1'b0;
            idex_flag_we     <= 1'b0;
            idex_jump        <= 1'b0;
            idex_br_z        <= 1'b0;
            idex_br_nz       <= 1'b0;
            idex_halt        <= 1'b0;
            idex_rd          <= 3'd0;
            idex_ra          <= 3'd0;
            idex_rb          <= 3'd0;
            idex_rdata_a     <= 8'h00;
            idex_rdata_b     <= 8'h00;
            idex_imm8        <= 8'h00;

            exmem_valid      <= 1'b0;
            exmem_reg_we     <= 1'b0;
            exmem_mem_to_reg <= 1'b0;
            exmem_mem_we     <= 1'b0;
            exmem_halt       <= 1'b0;
            exmem_rd         <= 3'd0;
            exmem_alu_result <= 8'h00;
            exmem_addr       <= 8'h00;
            exmem_store_data <= 8'h00;

            memwb_valid      <= 1'b0;
            memwb_reg_we     <= 1'b0;
            memwb_halt       <= 1'b0;
            memwb_rd         <= 3'd0;
            memwb_result     <= 8'h00;
        end else if (!halted) begin
            // 1. PC and IF/ID update
            if (take_branch) begin
                pc         <= idex_imm8;
                ifid_valid <= 1'b0;
                ifid_instr <= 16'h0000;
            end else if (halt_in_ex_or_later) begin
                pc         <= pc;
                ifid_valid <= 1'b0;
                ifid_instr <= 16'h0000;
            end else if (stall) begin
                pc         <= pc;
                ifid_valid <= ifid_valid;
                ifid_instr <= ifid_instr;
            end else begin
                pc         <= pc + 8'd1;
                ifid_valid <= 1'b1;
                ifid_instr <= imem_instr;
            end

            // 2. ID/EX update
            if (take_branch || halt_in_ex_or_later || stall || !ifid_valid) begin
                idex_valid       <= 1'b0;
                idex_alu_op      <= 3'd0;
                idex_alu_src_imm <= 1'b0;
                idex_uses_a      <= 1'b0;
                idex_uses_b      <= 1'b0;
                idex_reg_we      <= 1'b0;
                idex_mem_to_reg  <= 1'b0;
                idex_mem_we      <= 1'b0;
                idex_flag_we     <= 1'b0;
                idex_jump        <= 1'b0;
                idex_br_z        <= 1'b0;
                idex_br_nz       <= 1'b0;
                idex_halt        <= 1'b0;
                idex_rd          <= 3'd0;
                idex_ra          <= 3'd0;
                idex_rb          <= 3'd0;
                idex_rdata_a     <= 8'h00;
                idex_rdata_b     <= 8'h00;
                idex_imm8        <= 8'h00;
            end else begin
                idex_valid       <= 1'b1;
                idex_alu_op      <= id_alu_op;
                idex_alu_src_imm <= id_alu_src_imm;
                idex_uses_a      <= id_uses_a;
                idex_uses_b      <= id_uses_b;
                idex_reg_we      <= id_reg_we;
                idex_mem_to_reg  <= id_mem_to_reg;
                idex_mem_we      <= id_mem_we;
                idex_flag_we     <= id_flag_we;
                idex_jump        <= id_jump;
                idex_br_z        <= id_br_z;
                idex_br_nz       <= id_br_nz;
                idex_halt        <= id_halt;
                idex_rd          <= id_rd;
                idex_ra          <= id_ra;
                idex_rb          <= id_rb;
                idex_rdata_a     <= id_rdata_a;
                idex_rdata_b     <= id_rdata_b;
                idex_imm8        <= id_imm8;
            end

            // 3. Architectural Flags update in EX
            if (idex_valid && idex_flag_we) begin
                flag_z <= alu_z;
                flag_c <= alu_c;
            end

            // 4. EX/MEM update
            exmem_valid      <= idex_valid;
            exmem_reg_we     <= idex_valid && idex_reg_we;
            exmem_mem_to_reg <= idex_valid && idex_mem_to_reg;
            exmem_mem_we     <= idex_valid && idex_mem_we;
            exmem_halt       <= idex_valid && idex_halt;
            exmem_rd         <= idex_rd;
            exmem_alu_result <= alu_result;
            exmem_addr       <= ex_opa;
            exmem_store_data <= ex_opb;

            // 5. MEM/WB update
            memwb_valid      <= exmem_valid;
            memwb_reg_we     <= exmem_valid && exmem_reg_we;
            memwb_halt       <= exmem_valid && exmem_halt;
            memwb_rd         <= exmem_rd;
            memwb_result     <= mem_result;
        end
    end

    // =========================================================================
    // Top-level Observation Outputs
    // =========================================================================
    assign halted     = memwb_valid && memwb_halt;
    assign pc_out     = pc;
    assign flags_out  = {flag_z, flag_c};
    assign instr_done = memwb_valid;

endmodule
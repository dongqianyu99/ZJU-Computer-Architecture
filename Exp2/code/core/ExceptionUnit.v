`timescale 1ns / 1ps

module ExceptionUnit(
    input clk, rst,

    // csr read/write concerning
    input csr_rw_in,
    input[1:0] csr_wsc_mode_in,
    input csr_w_imm_mux,
    input[11:0] csr_rw_addr_in,
    input[31:0] csr_w_data_reg,
    input[4:0] csr_w_data_imm,
    output[31:0] csr_r_data_out,

    // exception and interrupt
    input interrupt,
    input illegal_inst,
    input l_access_fault,
    input s_access_fault,
    input ecall_m,

    input mret,

    input[31:0] epc_cur,
    input[31:0] epc_next,
    output[31:0] PC_redirect,
    output redirect_mux,

    output reg_FD_flush, reg_DE_flush, reg_EM_flush, reg_MW_flush, 
    output RegWrite_cancel
);

    reg[11:0] csr_raddr, csr_waddr;
    reg[31:0] csr_wdata;
    reg csr_w;
    reg[1:0] csr_wsc;

    wire[31:0] mstatus;

    CSRRegs csr(.clk(clk),.rst(rst),.csr_w(csr_w),.raddr(csr_raddr),.waddr(csr_waddr),
        .wdata(csr_wdata),.rdata(csr_r_data_out),.mstatus(mstatus),.csr_wsc_mode(csr_wsc)
        .is_trap(trap),.is_mret(mret),.mepc(mepc),.mcause(mcause),.mtval(mtval),.mtvec(mtvec),.mepc_o(mepc_o));

    //According to the diagram, design the Exception Unit

    assign exception = illegal_inst | l_access_fault | s_access_fault | ecall_m;
    assign trap = interrupt | exception;

    always @ * begin
        //csr read/write concerning
        if (csr_rw_in) begin
            csr_w <= 1;
            csr_raddr <= csr_rw_addr_in;
            csr_waddr <= csr_rw_addr_in;
            csr_wdata <= csr_w_imm_mux ? csr_w_data_imm : csr_w_data_reg;
            csr_wsc <= csr_wsc_mode_in;
        end
        else begin
            csr_w <= 0;
            csr_raddr <= 0;
            csr_waddr <= 0;
            csr_wdata <= 0;
            csr_wsc <= 0;
        end

        // trap case
        if (trap) begin
            reg_FD_flush <= 1;
            reg_DE_flush <= 1;
            reg_EM_flush <= 1;
            reg_MW_flush <= 1;
            RegWrite_cancel <= 1;
        end
        else begin
            reg_FD_flush <= 0;
            reg_DE_flush <= 0;
            reg_EM_flush <= 0;
            reg_MW_flush <= 0;
            RegWrite_cancel <= 0;
        end

        // interrupt & exception
        if (interrupt & mstatus[3]) begin // forbid interruption when MIE = 0
            mepc <= epc_next;
            mcause <= 32'h80000000;
            mtval <= 0;
        end
        else if (illegal_inst) begin
            mepc <= epc_cur;
            mcause <= 2;
            mtval <= 0;
        end
        else if (l_access_fault) begin
            mepc <= epc_cur;
            mcause <= 5;
            mtval <= 0;
        end
        else if (s_access_fault) begin
            mepc <= epc_cur;
            mcause <= 7;
            mtval <= 0;
        end
        else if (ecall_m) begin
            mepc <= epc_cur;
            mcause <= 11;
            mtval <= 0;
        end
        else begin
            mepc <= 0;
            mcause <= 0;
            mtval <= 0;
        end

endmodule
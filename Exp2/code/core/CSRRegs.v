`timescale 1ns / 1ps

module CSRRegs(
    input clk, rst,
    input[11:0] raddr, waddr, // 读/写地址
    input[31:0] wdata, // 写入数据
    input csr_w, // 写入使能信号
    input[1:0] csr_wsc_mode, // 写入模式
    output[31:0] rdata, // 读取的数据
    output[31:0] mstatus, // mstatus 输出

    input is_trap,
    input is_mret,
    input [31: 0] mepc,
    input [31: 0] mcause,
    input [31: 0] mtval,
    input [31: 0] mtvec,
    output [31: 0] mepc_o
);

    reg[31:0] CSR [0:15];

    // Address mapping. The address is 12 bits, but only 4 bits are used in this module.
    // [11:7] 和 [5:3]作为 valid bits
    wire raddr_valid = raddr[11:7] == 5'h6 && raddr[5:3] == 3'h0;
    // [6] 和 [2:0] 作为实际地址
    wire[3:0] raddr_map = (raddr[6] << 3) + raddr[2:0];
    wire waddr_valid = waddr[11:7] == 5'h6 && waddr[5:3] == 3'h0;
    wire[3:0] waddr_map = (waddr[6] << 3) + waddr[2:0];

    // 0x300: mstatus -> CSR[0]
    // 0x305: mtvec -> CSR[5]
    // 0x341: mepc -> CSR[9]
    // 0x342: mcause -> CSR[10]
    // 0x343: mtval -> CSR[11]

    assign mstatus = CSR[0];
    assign mtvec = CSR[5];
    assign mepc_o = CSR[9];

    assign rdata = CSR[raddr_map];

    always@(posedge clk or posedge rst) begin
        if(rst) begin
			CSR[0] <= 32'h88; // MIE = 1; MPIE = 1;
			CSR[1] <= 0;
			CSR[2] <= 0;
			CSR[3] <= 0;
			CSR[4] <= 32'hfff;
			CSR[5] <= 0;
			CSR[6] <= 0;
			CSR[7] <= 0;
			CSR[8] <= 0;
			CSR[9] <= 0;
			CSR[10] <= 0;
			CSR[11] <= 0;
			CSR[12] <= 0;
			CSR[13] <= 0;
			CSR[14] <= 0;
			CSR[15] <= 0;
		end
        else if(csr_w) begin
            case(csr_wsc_mode)
                2'b01: CSR[waddr_map] = wdata; // 直接将 wdata 写入 CSR
                2'b10: CSR[waddr_map] = CSR[waddr_map] | wdata;
                2'b11: CSR[waddr_map] = CSR[waddr_map] & ~wdata;
                default: CSR[waddr_map] = wdata;
            endcase            
        end
        else if (is_trap) begin
            CSR[9] <= mepc;
            CSR[10] <= mcause;
            CSR[11] <= mtval;
            if (CSR[0][3] == 0) begin
                CSR[0][7] <= CSR[0][3]; // MPIE = MIE
                CSR[0][3] <= 0; // MIE = 0
            end 
            CSR[0][12:11] <= 2'b11; // MPP (不考虑别的模式)
        end
        else if (is_mret) begin
            CSR[9] <= mepc;
            CSR[10] <= mcause;
            CSR[11] <= mtval;
            CSR[0][3] <= CSR[0][7];
        end 
    end
endmodule
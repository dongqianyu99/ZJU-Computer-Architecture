`timescale 1ns / 1ps

module FU_div(
    input clk, EN,
    input[31:0] A, B,
    output[31:0] res,
    output finish
);

    wire res_valid;
    wire[63:0] divres;
    
    reg state;
    assign finish = res_valid & state;
    initial begin
        state = 0;
    end

    reg A_valid, B_valid;
    reg[31:0] A_reg, B_reg;

    //to fill sth.in
    always@(posedge clk) begin
        if(EN & ~state & ~res_valid) begin // state == 0 and res_valid == 0
            A_reg <= A;
            B_reg <= B;
            A_valid <= 1'b1;
            B_valid <= 1'b1;
            state <= 1;
        end
        else if (res_valid) begin
            A_valid <= 1'b0;
            B_valid <= 1'b0;
            state <= 0;
        end
    end

    divider div(.aclk(clk),
        .s_axis_dividend_tvalid(A_valid),
        .s_axis_dividend_tdata(A_reg),
        .s_axis_divisor_tvalid(B_valid), 
        .s_axis_divisor_tdata(B_reg),
        .m_axis_dout_tvalid(res_valid), 
        .m_axis_dout_tdata(divres)
    );

    assign res = divres[63:32];

endmodule
`timescale 1ps/1ps

module HazardDetectionUnit(
    input clk,
    input Branch_ID, rs1use_ID, rs2use_ID,
    input[1:0] hazard_optype_ID,
    input[4:0] rd_EXE, rd_MEM, rs1_ID, rs2_ID, rs2_EXE,
    // Branch_ID：是否是分支指令
    // rs1use_ID：是否使用rs1, rs2use_ID：是否使用rs2
    // hazard_optype_ID：当前指令（在ID阶段）指令类型
    // rd_EXE：EXE阶段的目的寄存器，rd_MEM：MEM阶段的目的寄存器
    // rs1_ID：ID阶段的rs1，rs2_ID：ID阶段的rs2，rs2_EXE：EXE阶段的rs2
    output PC_EN_IF, reg_FD_EN, reg_FD_stall, reg_FD_flush,
        reg_DE_EN, reg_DE_flush, reg_EM_EN, reg_EM_flush, reg_MW_EN,
    output forward_ctrl_ls,
    output[1:0] forward_ctrl_A, forward_ctrl_B
    // PC_EN_IF：IF阶段是否启用PC
    // reg_FD_EN, reg_DE_EN, reg_EM_EN, reg_MW_EN：是否启用寄存器
    // reg_FD_stall, reg_FD_flush, reg_DE_flush, reg_EM_flush：是否暂停或清空寄存器
    // forward_ctrl_ls：是否启用旁路
    // forward_ctrl_A, forward_ctrl_B：旁路控制
);
    //according to the diagram, design the Hazard Detection Unit

    // enable 所有 register
    assign reg_FD_EN = 1'b1;
    assign reg_DE_EN = 1'b1;
    assign reg_EM_EN = 1'b1;
    assign reg_MW_EN = 1'b1;

    reg[1:0] hazard_optype_EXE, hazard_optype_MEM;
    always@(posedge clk) begin
        hazard_optype_MEM <= hazard_optype_EXE;
        hazard_optype_EXE <= hazard_optype_ID & {2{~reg_DE_flush}};
    end

    parameter hazard_optype_ALU = 2'b01;
    parameter hazard_optype_LOAD = 2'b10;
    parameter hazard_optype_STORE = 2'b11;

    // 先考虑必须 stall 的情况: load-use hazard
    // IF ID EX MEM WB
    //            \
    //       IF ID EX MEM WB
    // 当前指令( ID 阶段)判断上一条指令（ EX 阶段）是否为 load 指令
    // 当前指令不能是 store 类型( load-use hazard )
    // 当前指令的 rs1 或 rs2 与上一条指令的 rd 相同
    wire load_use_stall = (hazard_optype_EXE == hazard_optype_LOAD) 
                          && (hazard_optype_ID != hazard_optype_STORE) 
                          && (rd_EXE)
                          && (rs1use_ID && rs1_ID == rd_EXE) || (rs2use_ID && rs2_ID == rd_EXE);
    assign PC_EN_IF = ~load_use_stall; // load-use hazard 时，IF 阶段暂停
    assign reg_FD_stall = load_use_stall; // IF 与 ID 间的寄存器不更新
    assign reg_FD_flush = load_use_stall; // IF 与 ID 间的寄存器 flush
    assign reg_DE_flush = load_use_stall; // ID 与 EX 间的寄存器 flush

    // 可以 foward 的情况: data hazard
    // 1. ALU 使用 EX 结果
    // IF ID EX MEM WB
    //         \
    //    IF ID EX MEM WB
    // 当前指令( ID 阶段)判断上一条指令（ EX 阶段）是否为 ALU 类型指令
    // 当前指令的 rs1 或 rs2 与上一条指令的 rd 相同
    wire rs1_forward_1 = (hazard_optype_EXE == hazard_optype_ALU)
                         && (rd_EXE)
                         && (rs1use_ID && rs1_ID == rd_EXE); 
    wire rs2_forward_1 = (hazard_optype_EXE == hazard_optype_ALU)
                         && (rd_EXE)
                         && (rs2use_ID && rs2_ID == rd_EXE);
    // 2. ALU 使用 MEM 结果
    // IF ID EX MEM WB
    //            \
    //             \
    //        IF ID EX MEM WB
    // 当前指令( ID 阶段)判断上上条指令（ MEM 阶段）是否为 ALU 类型指令
    // 当前指令的 rs1 或 rs2 与上上条指令的 rd 相同
    wire rs1_forward_2 = (hazard_optype_MEM == hazard_optype_ALU)
                         && (rd_MEM)
                         && (rs1use_ID && rs1_ID == rd_MEM);
    wire rs2_forward_2 = (hazard_optype_MEM == hazard_optype_ALU)
                         && (rd_MEM)
                         && (rs2use_ID && rs2_ID == rd_MEM); 
    // 3. ALU 使用 load 结果
    // IF ID EX MEM WB
    //            \
    //             \
    //        IF ID EX MEM WB
    // 当前指令( ID 阶段)判断上上条指令（ MEM 阶段）是否为 load 类型指令
    // 当前指令的 rs1 或 rs2 与上上条指令的 rd 相同
    wire rs1_forward_3 = (hazard_optype_MEM == hazard_optype_LOAD)
                         && (rd_MEM)
                         && (rs1use_ID && rs1_ID == rd_MEM);
    wire rs2_forward_3 = (hazard_optype_MEM == hazard_optype_LOAD)
                         && (rd_MEM)
                         && (rs2use_ID && rs2_ID == rd_MEM);

    // forwarding 控制，选择正确的旁路
    // rs*_forward_1 -> 01; rs*_forward_2 -> 10; rs*_forward_3 -> 11
    assign forward_ctrl_A = {2{rs1_forward_1}} & 2'b01 |
                            {2{rs1_forward_2}} & 2'b10 |
                            {2{rs1_forward_3}} & 2'b11;

    assign forward_ctrl_B = {2{rs2_forward_1}} & 2'b01 |
                            {2{rs2_forward_2}} & 2'b10 |
                            {2{rs2_forward_3}} & 2'b11;

    // Branch 预测错误
    assign reg_FD_flush = Branch_ID; // IF 与 ID 间的寄存器 flush

    // load 出来的数据被立刻存入
    // IF ID EX MEM WB
    //            \
    //    IF ID EX MEM WB
    assign forward_ctrl_ls = (rs2_EXE == rd_MEM) 
                             && (hazard_optype_MEM == hazard_optype_LOAD) 
                             && (hazard_optype_EXE == hazard_optype_STORE);


endmodule
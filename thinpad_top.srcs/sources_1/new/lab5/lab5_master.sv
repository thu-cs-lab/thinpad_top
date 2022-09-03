module lab5_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic clk_i,
    input logic rst_i,

    // TODO: 添加需要的控制信号，例如按键开关？

    // wishbone master
    output logic wb_cyc_o,
    output logic wb_stb_o,
    input logic wb_ack_i,
    output logic [ADDR_WIDTH-1:0] wb_adr_o,
    output logic [DATA_WIDTH-1:0] wb_dat_o,
    input logic [DATA_WIDTH-1:0] wb_dat_i,
    output logic [DATA_WIDTH/8-1:0] wb_sel_o,
    output logic wb_we_o
);

  // TODO: 实现实验 5 的内存+串口 Master

endmodule

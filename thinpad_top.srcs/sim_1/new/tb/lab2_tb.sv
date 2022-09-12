`timescale 1ns / 1ps
module lab2_tb;

  wire clk_50M, clk_11M0592;

  reg push_btn;   // BTN5 按钮开关，带消抖电路，按下时为 1
  reg reset_btn;  // BTN6 复位按钮，带消抖电路，按下时为 1

  reg [3:0] touch_btn; // BTN1~BTN4，按钮开关，按下时为 1
  reg [31:0] dip_sw;   // 32 位拨码开关，拨到“ON”时为 1

  wire [15:0] leds;  // 16 位 LED，输出时 1 点亮
  wire [7:0] dpy0;   // 数码管低位信号，包括小数点，输出 1 点亮
  wire [7:0] dpy1;   // 数码管高位信号，包括小数点，输出 1 点亮

  initial begin
    // 在这里可以自定义测试输入序列，例如：
    dip_sw = 32'h0;
    touch_btn = 0;
    reset_btn = 0;
    push_btn = 0;

    #100;
    reset_btn = 1;
    #100;
    reset_btn = 0;
    
    for (integer i = 0; i < 20; i = i + 1) begin
      #100;  // 等待 100ns
      push_btn = 1;  // 按下 push_btn 按钮
      #100;  // 等待 100ns
      push_btn = 0;  // 松开 push_btn 按钮
    end

    #10000 $finish;
  end

  // 待测试用户设计
  lab2_top dut (
      .clk_50M(clk_50M),
      .clk_11M0592(clk_11M0592),
      .push_btn(push_btn),
      .reset_btn(reset_btn),
      .touch_btn(touch_btn),
      .dip_sw(dip_sw),
      .leds(leds),
      .dpy1(dpy1),
      .dpy0(dpy0),

      .txd(),
      .rxd(1'b1),
      .uart_rdn(),
      .uart_wrn(),
      .uart_dataready(1'b0),
      .uart_tbre(1'b0),
      .uart_tsre(1'b0),
      .base_ram_data(),
      .base_ram_addr(),
      .base_ram_ce_n(),
      .base_ram_oe_n(),
      .base_ram_we_n(),
      .base_ram_be_n(),
      .ext_ram_data(),
      .ext_ram_addr(),
      .ext_ram_ce_n(),
      .ext_ram_oe_n(),
      .ext_ram_we_n(),
      .ext_ram_be_n(),
      .flash_d(),
      .flash_a(),
      .flash_rp_n(),
      .flash_vpen(),
      .flash_oe_n(),
      .flash_ce_n(),
      .flash_byte_n(),
      .flash_we_n()
  );

  // 时钟源
  clock osc (
      .clk_11M0592(clk_11M0592),
      .clk_50M    (clk_50M)
  );

endmodule

`default_nettype none

module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮开关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时为 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时为 1
    output wire [15:0] leds,       // 16 位 LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信号
    output wire uart_rdn,        // 读串口信号，低有效
    output wire uart_wrn,        // 写串口信号，低有效
    input  wire uart_dataready,  // 串口数据准备好
    input  wire uart_tbre,       // 发送数据标志
    input  wire uart_tsre,       // 数据发送完毕标志

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共享
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire base_ram_ce_n,  // BaseRAM 片选，低有效
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有效
    output wire base_ram_we_n,  // BaseRAM 写使能，低有效

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire ext_ram_ce_n,  // ExtRAM 片选，低有效
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有效
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有效

    // 直连串口信号
    output wire txd,  // 直连串口发送端
    input  wire rxd,  // 直连串口接收端

    // Flash 存储器信号，参考 JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效，16bit 模式无意义
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,  // Flash 片选信号，低有效
    output wire flash_oe_n,  // Flash 读使能信号，低有效
    output wire flash_we_n,  // Flash 写使能信号，低有效
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash 的 16 位模式时请设为 1

    // USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素，3 位
    output wire [2:0] video_green,  // 绿色像素，3 位
    output wire [1:0] video_blue,   // 蓝色像素，2 位
    output wire       video_hsync,  // 行同步（水平同步）信号
    output wire       video_vsync,  // 场同步（垂直同步）信号
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐区
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked, clk_10M, clk_20M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设置
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设置
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出，"1"表示时钟稳定，
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  always_ff @(posedge clk_10M or posedge reset_of_clk10M) begin
    if (reset_of_clk10M) begin
      // Your Code
    end else begin
      // Your Code
    end
  end

  // 不使用内存、串口时，禁用其使能信号
  assign base_ram_ce_n = 1'b1;
  assign base_ram_oe_n = 1'b1;
  assign base_ram_we_n = 1'b1;

  assign ext_ram_ce_n = 1'b1;
  assign ext_ram_oe_n = 1'b1;
  assign ext_ram_we_n = 1'b1;

  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  // 数码管连接关系示意图，dpy1 同理
  // p=dpy0[0] // ---a---
  // c=dpy0[1] // |     |
  // d=dpy0[2] // f     b
  // e=dpy0[3] // |     |
  // b=dpy0[4] // ---g---
  // a=dpy0[5] // |     |
  // f=dpy0[6] // e     c
  // g=dpy0[7] // |     |
  //           // ---d---  p

  // 7 段数码管译码器演示，将 number 用 16 进制显示在数码管上面
  logic [7:0] number;
  SEG7_LUT segL (
      .oSEG1(dpy0),
      .iDIG (number[3:0])
  );  // dpy0 是低位数码管
  SEG7_LUT segH (
      .oSEG1(dpy1),
      .iDIG (number[7:4])
  );  // dpy1 是高位数码管

  logic [15:0] led_bits;
  assign leds = led_bits;

  always_ff @(posedge clk_50M) begin
    if (reset_btn) begin  // 复位按下，设置 LED 为初始值
      led_bits <= 16'h1;
    end else if (push_btn) begin  // 每次按下按钮开关，LED 循环左移
      led_bits <= {led_bits[14:0], led_bits[15]};
    end
  end

  // 直连串口接收发送演示，从直连串口收到的数据再发送出去
  logic [7:0] ext_uart_rx;
  logic [7:0] ext_uart_buffer, ext_uart_tx;
  logic ext_uart_ready, ext_uart_clear, ext_uart_busy;
  logic ext_uart_start, ext_uart_avai;

  assign number = ext_uart_buffer;

  // 接收模块，9600 无检验位
  async_receiver #(
      .ClkFrequency(50000000),
      .Baud(9600)
  ) ext_uart_r (
      .clk           (clk_50M),         // 外部时钟信号
      .RxD           (rxd),             // 外部串行信号输入
      .RxD_data_ready(ext_uart_ready),  // 数据接收到标志
      .RxD_clear     (ext_uart_clear),  // 清除接收标志
      .RxD_data      (ext_uart_rx)      // 接收到的一字节数据
  );

  assign ext_uart_clear = ext_uart_ready; // 收到数据的同时，清除标志，因为数据已取到 ext_uart_buffer 中
  always_ff @(posedge clk_50M) begin  // 接收到缓冲区 ext_uart_buffer
    if (ext_uart_ready) begin
      ext_uart_buffer <= ext_uart_rx;
      ext_uart_avai   <= 1;
    end else if (!ext_uart_busy && ext_uart_avai) begin
      ext_uart_avai <= 0;
    end
  end
  always_ff @(posedge clk_50M) begin  // 将缓冲区 ext_uart_buffer 发送出去
    if (!ext_uart_busy && ext_uart_avai) begin
      ext_uart_tx <= ext_uart_buffer;
      ext_uart_start <= 1;
    end else begin
      ext_uart_start <= 0;
    end
  end

  // 发送模块，9600 无检验位
  async_transmitter #(
      .ClkFrequency(50000000),
      .Baud(9600)
  ) ext_uart_t (
      .clk      (clk_50M),         // 外部时钟信号
      .TxD      (txd),             // 串行信号输出
      .TxD_busy (ext_uart_busy),   // 发送器忙状态指示
      .TxD_start(ext_uart_start),  // 开始发送信号
      .TxD_data (ext_uart_tx)      // 待发送的数据
  );

  // 图像输出演示，分辨率 800x600@72Hz，像素时钟为 50MHz
  logic [11:0] hdata;
  assign video_red   = hdata < 266 ? 3'b111 : 0;  // 红色竖条
  assign video_green = hdata < 532 && hdata >= 266 ? 3'b111 : 0;  // 绿色竖条
  assign video_blue  = hdata >= 532 ? 2'b11 : 0;  // 蓝色竖条
  assign video_clk   = clk_50M;
  vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at72 (
      .clk        (clk_50M),
      .hdata      (hdata),        // 横坐标
      .vdata      (),             // 纵坐标
      .hsync      (video_hsync),
      .vsync      (video_vsync),
      .data_enable(video_de)
  );
  /* =========== Demo code end =========== */

endmodule

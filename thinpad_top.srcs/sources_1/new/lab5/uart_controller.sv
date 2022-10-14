module uart_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,

    parameter CLK_FREQ = 50_000_000,
    parameter BAUD = 115200
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // uart interface
    output reg uart_txd_o,
    input  wire uart_rxd_i
);

  localparam REG_DATA = 8'h00;
  localparam REG_STATUS = 8'h05;

  // uart transmitter
  logic txd_start;
  logic txd_busy;
  logic [7:0] txd_data;

  async_transmitter #(
      .ClkFrequency(CLK_FREQ),
      .Baud        (BAUD)
  ) u_async_transmitter (
      .clk      (clk_i),
      .TxD_start(txd_start),
      .TxD_data (txd_data),
      .TxD      (uart_txd_o),
      .TxD_busy (txd_busy)
  );

  // uart receiver
  logic rxd_data_ready;
  logic [7:0] rxd_data;
  logic rxd_clear;

  async_receiver #(
      .ClkFrequency(CLK_FREQ),
      .Baud        (BAUD)
  ) u_async_receiver (
      .clk           (clk_i),
      .RxD           (uart_rxd_i),
      .RxD_data_ready(rxd_data_ready),
      .RxD_clear     (rxd_clear),
      .RxD_data      (rxd_data)
  );

  /*-- internal registers --*/
  wire [7:0] reg_status = {2'b0, ~txd_busy, 4'b0, rxd_data_ready};

  /*-- wishbone fsm --*/
  always_ff @(posedge clk_i) begin
    if (rst_i)
      wb_ack_o <= 0;
    else
      // every request get ACK-ed immediately
      if (wb_ack_o) begin
        wb_ack_o <= 0;
      end else begin
        wb_ack_o <= wb_stb_i;
      end
  end

  // write logic
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      txd_start <= 0;
    end else if(wb_stb_i && wb_we_i) begin
      case (wb_adr_i[7:0])
        REG_DATA: begin
          if(wb_sel_i[0]) begin
            txd_data  <= wb_dat_i[7:0];
            txd_start <= 1;
          end
        end

        default: ;  // do nothing
      endcase
    end else begin
      txd_start <= 0;
    end
  end

  // read logic
  always_ff @(posedge clk_i) begin
    if(rst_i) begin
      rxd_clear <= 1;  // clear rxd to initialize dataready
    end else if(wb_stb_i && !wb_we_i) begin
      case (wb_adr_i[7:0])
        REG_DATA: begin
          if (wb_sel_i[0]) wb_dat_o[7:0] <= rxd_data;
          if (wb_sel_i[1]) wb_dat_o[15:8] <= rxd_data;
          if (wb_sel_i[2]) wb_dat_o[23:16] <= rxd_data;
          if (wb_sel_i[3]) wb_dat_o[31:24] <= rxd_data;

          rxd_clear <= 1;
        end

        REG_STATUS: begin
          if (wb_sel_i[0]) wb_dat_o[7:0] <= reg_status;
          if (wb_sel_i[1]) wb_dat_o[15:8] <= reg_status;
          if (wb_sel_i[2]) wb_dat_o[23:16] <= reg_status;
          if (wb_sel_i[3]) wb_dat_o[31:24] <= reg_status;
        end

        default: ;  // do nothing
      endcase
    end else begin
      rxd_clear <= 0;
    end
  end

endmodule

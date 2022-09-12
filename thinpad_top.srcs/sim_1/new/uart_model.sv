`timescale 1ns / 1ps

module uart_model #(
    parameter BAUD = 115200
) (
    input  wire rxd,
    output wire txd
);

  wire uart_clk;
  clock clock_gen (
      .clk_50M    (),
      .clk_11M0592(uart_clk)
  );

  // TXD Side
  reg txd_start = 0;
  reg [7:0] txd_data;
  wire txd_busy;

  async_transmitter #(
      .ClkFrequency(11_059_200),
      .Baud        (BAUD)
  ) uart_tx (
      .clk(uart_clk),
      .TxD(txd),

      .TxD_start(txd_start),
      .TxD_data (txd_data),
      .TxD_busy (txd_busy)
  );

  task pc_send_byte;
    input [7:0] arg;
    begin
      @(posedge uart_clk);
      txd_data  = arg;
      txd_start = 1;
      @(posedge uart_clk);
      txd_start = 0;
      @(txd_busy == 0);
    end
  endtask

  // RXD Side
  wire rxd_data_ready;
  reg rxd_clear = 0;
  wire [7:0] rxd_data;

  async_receiver #(
      .ClkFrequency(11_059_200),
      .Baud        (BAUD)
  ) uart_rx (
      .clk(uart_clk),
      .RxD(rxd),

      .RxD_data_ready(rxd_data_ready),
      .RxD_clear     (rxd_clear),
      .RxD_data      (rxd_data)
  );

  always begin
    wait (rxd_data_ready == 1);
    $write("[%0t]: uart received 0x%02x", $time, rxd_data);
    
    if (rxd_data >= 8'h21 && rxd_data <= 8'h7E)
      $write(", ASCII: %c\n", rxd_data);
    else
      $write("\n");
    
    @(posedge uart_clk);
    rxd_clear = 1;
    @(posedge uart_clk);
    rxd_clear = 0;

    wait(rxd_data_ready == 0);
  end

endmodule

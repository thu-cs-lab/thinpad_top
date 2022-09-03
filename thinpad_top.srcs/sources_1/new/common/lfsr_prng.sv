/*

Copyright (c) 2016 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * LFSR PRNG
 */
module lfsr_prng #(
    // width of data output
    parameter DATA_WIDTH = 32,

    // invert output
    parameter INVERT = 0
) (
    input wire                  clk,
    input wire                  load,
    input wire [DATA_WIDTH-1:0] seed,

    input  wire                  enable,
    output wire [DATA_WIDTH-1:0] data_out
);

  /*
    Ports:
    clk         Clock input
    load        Load input, set state to seed
    seed        Seed input
    enable      Generate new output data
    data_out    LFSR output (DATA_WIDTH bits)

    Parameters:
    INVERT      Bitwise invert PRBS output.
    DATA_WIDTH  Specify width of output data bus.
  */

  reg  [DATA_WIDTH-1:0] state_reg;
  reg  [DATA_WIDTH-1:0] output_reg;

  wire [DATA_WIDTH-1:0] lfsr_data;
  wire [DATA_WIDTH-1:0] lfsr_state;

  assign data_out = output_reg;

  // Maximal Length LFSR Feedback Terms
  // Taken from https://users.ece.cmu.edu/~koopman/lfsr/
  // MSB is suppressed for lfsr module
  parameter [63:0] MAX_POLY_TABLE[0:63] = {
    'h0,
    'h0,
    'h0,
    4'h9,
    5'h9,
    6'h21,
    7'h41,
    8'h71,
    9'h21,
    10'h81,
    11'h201,
    12'h941,
    13'h1601,
    14'h2a01,
    15'h4001,
    16'h6801,
    17'h4001,
    18'h32001,
    19'h64001,
    20'h20001,
    21'h80001,
    22'h200001,
    23'h40001,
    24'hb00001,
    25'h400001,
    26'h3100001,
    27'h6400001,
    28'h2000001,
    29'h8000001,
    30'h25000001,
    31'h10000001,
    32'hea000001,
    33'h128000001,
    34'h338000001,
    35'h200000001,
    36'hdc0000001,
    37'h1f00000001,
    38'h2300000001,
    39'h800000001,
    40'h3800000001,
    41'h4000000001,
    42'h3e000000001,
    43'h1a000000001,
    44'h4c000000001,
    45'h160000000001,
    46'h3a4000000001,
    47'h40000000001,
    48'hda0000000001,
    49'h380000000001,
    50'h1c00000000001,
    51'h5200000000001,
    52'h2000000000001,
    53'h18800000000001,
    54'h1f000000000001,
    55'h62000000000001,
    56'h52000000000001,
    57'hd0000000000001,
    58'h230000000000001,
    59'h5e0000000000001,
    60'h800000000000001,
    61'h1900000000000001,
    62'hb00000000000001,
    63'h4000000000000001,
    64'hb000000000000001
  };

  lfsr #(
      .LFSR_WIDTH(DATA_WIDTH),
      .LFSR_POLY(MAX_POLY_TABLE[DATA_WIDTH-1]),
      .LFSR_CONFIG("FIBONACCI"),
      .LFSR_FEED_FORWARD(0),
      .REVERSE(1),
      .DATA_WIDTH(DATA_WIDTH)
  ) lfsr_inst (
      .data_in  ({DATA_WIDTH{1'b0}}),
      .state_in (state_reg),
      .data_out (lfsr_data),
      .state_out(lfsr_state)
  );

  always @* begin
    if (INVERT) begin
      output_reg <= ~lfsr_data;
    end else begin
      output_reg <= lfsr_data;
    end
  end

  always @(posedge clk) begin
    if (load) begin
      state_reg <= seed;
    end else begin
      if (enable) begin
        state_reg <= lfsr_state;
      end
    end
  end

`ifdef SIMULATION
  initial begin
    $display("LFSR PRNG");
    $display("  DATA_WIDTH: %d", DATA_WIDTH);
    $display("  INVERT: %d", INVERT);
    $display("  POLY: %x", MAX_POLY_TABLE[DATA_WIDTH-1]);
  end
`endif

endmodule

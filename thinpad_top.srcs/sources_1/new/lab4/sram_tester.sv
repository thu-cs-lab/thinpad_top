module sram_tester #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,

    parameter ADDR_BASE   = 32'h8000_0000,
    parameter ADDR_MASK   = 32'h007F_FFFF,
    parameter TEST_ROUNDS = 1000
) (
    input wire clk_i,
    input wire rst_i,

    input wire start,
    input wire [31:0] random_seed,

    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o,

    // status signals
    output reg done,
    output reg error,
    output reg [31:0] error_round,
    output reg [ADDR_WIDTH-1:0] error_addr,
    output reg [DATA_WIDTH-1:0] error_read_data,
    output reg [DATA_WIDTH-1:0] error_expected_data
);

  localparam RAM_ADDR_WIDTH = $clog2(ADDR_MASK); // ceil to correct bits

  typedef enum logic [3:0] {
    ST_IDLE,

    ST_WRITE_ADR,
    ST_WRITE_DAT,
    ST_WRITE_ACTION,

    ST_READ_ADR,
    ST_READ_DAT,
    ST_READ_ACTION,

    ST_ERROR,
    ST_DONE
  } state_t;

  logic [31:0] count;
  logic [DATA_WIDTH-1:0] data_expected;
  logic [DATA_WIDTH-1:0] data_mask;

  state_t state, state_n;

  always_comb begin
    state_n = state;
    case (state)
      ST_IDLE: begin
        // start test sequence
        if (start) state_n = ST_WRITE_ADR;
      end

      ST_WRITE_ADR: begin
        if (count == TEST_ROUNDS - 1) state_n = ST_READ_ADR;
        else state_n = ST_WRITE_DAT;
      end

      ST_WRITE_DAT: begin
        state_n = ST_WRITE_ACTION;
      end

      ST_WRITE_ACTION: begin
        // wait for ack
        if (wb_ack_i) state_n = ST_WRITE_ADR;
      end

      ST_READ_ADR: begin
        if (count == TEST_ROUNDS - 1) state_n = ST_DONE;
        else state_n = ST_READ_DAT;
      end

      ST_READ_DAT: begin
        state_n = ST_READ_ACTION;
      end

      ST_READ_ACTION: begin
        if (wb_ack_i) begin
          if ((wb_dat_i & data_mask) != data_expected) state_n = ST_ERROR;
          else state_n = ST_READ_ADR;
        end
      end

      ST_ERROR: begin
        state_n = ST_ERROR;
      end

      ST_DONE: begin
        state_n = ST_DONE;
      end

      default: begin
        state_n = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      state <= ST_IDLE;
    end else begin
      state <= state_n;
    end
  end

  // test cycle counting
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      count <= '0;
    end else if (state == ST_WRITE_ADR || state == ST_READ_ADR) begin
      count <= count + 'd1;
      if (count == TEST_ROUNDS - 1) begin
        count <= '0;
      end
    end
  end

  // rng control
  logic rng_load;
  logic rng_addr_enable, rng_data_enable;
  always_comb begin
    rng_load = 0;

    case (state)
      ST_IDLE: begin
        if (start) rng_load = 1;
      end

      ST_WRITE_ADR: begin
        if (count == TEST_ROUNDS - 1) rng_load = 1;
      end
    endcase
  end

  always_comb begin
    rng_addr_enable = 0;
    rng_data_enable = 0;

    case (state)
      ST_WRITE_ADR, ST_READ_ADR: begin
        rng_addr_enable = 1;
      end

      ST_WRITE_DAT, ST_READ_DAT: begin
        rng_data_enable = 1;
      end
    endcase
  end

  // address prng
  logic [RAM_ADDR_WIDTH-1:0] rng_addr;
  lfsr_prng #(
      .DATA_WIDTH(RAM_ADDR_WIDTH),
      .INVERT    (0)
  ) u_prng_addr (
      .clk (clk_i),
      .load(rng_load),
      .seed(random_seed | 32'h1),

      .enable  (rng_addr_enable),
      .data_out(rng_addr)
  );


  // data prng
  logic [DATA_WIDTH-1:0] rng_data;
  lfsr_prng #(
      .DATA_WIDTH(DATA_WIDTH),
      .INVERT    (0)
  ) u_prng_data (
      .clk (clk_i),
      .load(rng_load),
      .seed(random_seed | 32'h1),

      .enable  (rng_data_enable),
      .data_out(rng_data)
  );

  // address and data buffer
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      wb_dat_o <= '0;
      wb_adr_o <= '0;
      data_expected <= '0;
    end else begin
      case (state)
        ST_WRITE_ADR, ST_READ_ADR: begin
          wb_adr_o <= ADDR_BASE | (rng_addr & ADDR_MASK);
        end

        ST_WRITE_DAT: begin
          wb_dat_o <= rng_data & data_mask;
        end

        ST_READ_DAT: begin
          data_expected <= rng_data & data_mask;
        end
      endcase
    end
  end

  // wishbone bus
  assign wb_cyc_o = wb_stb_o;

  genvar i;
  for (i = 0; i < DATA_WIDTH / 8; i = i + 1) begin
    assign data_mask[i*8+:8] = wb_sel_o[i] ? 8'hFF : 8'h00;
  end

  always_comb begin
    wb_we_o = (state == ST_WRITE_ACTION);
    wb_stb_o = (state == ST_READ_ACTION || state == ST_WRITE_ACTION);
  end

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      wb_sel_o <= '0;
    end else begin
      if (state == ST_READ_ADR || state == ST_WRITE_ADR) begin
        case (wb_adr_o[1:0])
          2'b00: wb_sel_o <= 4'b1111;  // full word
          2'b10: wb_sel_o <= 4'b1100;  // half word
          2'b01: wb_sel_o <= 4'b0010;  // byte
          2'b11: wb_sel_o <= 4'b1000;  // byte
        endcase
      end
    end
  end

  // status output
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      done <= 0;
      error <= 0;

      error_round <= '0;
      error_addr <= '0;
      error_read_data <= '0;
      error_expected_data <= '0;
    end else begin
      case (state)
        ST_DONE: begin
          done  <= 1;
          error <= 0;
        end

        ST_ERROR: begin
          done <= 0;
          error <= 1;

          error_round <= count;
          error_addr <= wb_adr_o;
          error_read_data <= wb_dat_i;
          error_expected_data <= data_expected;
        end

        default: begin
          done  <= 0;
          error <= 0;
        end
      endcase
    end
  end

endmodule

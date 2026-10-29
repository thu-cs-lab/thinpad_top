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
  localparam ADDR_ZEROS = ADDR_WIDTH - RAM_ADDR_WIDTH;
  localparam RAM_WORD_ADDR_WIDTH = RAM_ADDR_WIDTH - 2;

  typedef enum logic [3:0] {
    ST_IDLE,

    ST_WRITE,
    ST_WRITE_ACTION,

    ST_READ,
    ST_READ_ACTION,

    ST_ERROR,
    ST_DONE
  } state_t;

  logic [31:0] count;
  logic [DATA_WIDTH-1:0] data_expected;
  logic [DATA_WIDTH-1:0] data_mask;  // mask out rng for write
  logic [DATA_WIDTH/8-1:0] read_compare;  // byte read compare result

  state_t state, state_n;

  always_comb begin
    state_n = state;
    case (state)
      ST_IDLE: begin
        // start test sequence
        if (start) state_n = ST_WRITE;
      end

      ST_WRITE: begin
        if (count == TEST_ROUNDS) state_n = ST_READ;
        else state_n = ST_WRITE_ACTION;
      end

      ST_WRITE_ACTION: begin
        // wait for ack
        if (wb_ack_i) state_n = ST_WRITE;
      end

      ST_READ: begin
        if (count == TEST_ROUNDS) state_n = ST_DONE;
        else state_n = ST_READ_ACTION;
      end

      ST_READ_ACTION: begin
        if (wb_ack_i) begin
          if (!(&read_compare)) state_n = ST_ERROR;
          else state_n = ST_READ;
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
    end else if (state == ST_WRITE || state == ST_READ) begin
      count <= count + 'd1;
      if (count == TEST_ROUNDS) begin
        count <= '0;
      end
    end
  end

  // rng control
  logic rng_load;
  always_comb begin
    rng_load = 0;
    case (state)
      ST_IDLE: begin
        if (start) rng_load = 1;
      end

      ST_WRITE: begin
        if (count == TEST_ROUNDS) rng_load = 1;
      end

      default: rng_load = 0;
    endcase
  end

  logic rng_enable;
  always_comb begin
    rng_enable = (state == ST_WRITE) || (state == ST_READ);
  end

  // Generate SRAM word addresses directly to avoid byte-address aliases.
  logic [RAM_WORD_ADDR_WIDTH-1:0] rng_word_addr;
  lfsr_prng #(
      .DATA_WIDTH(RAM_WORD_ADDR_WIDTH),
      .INVERT    (0)
  ) u_prng_addr (
      .clk (clk_i),
      .load(rng_load),
      .seed(RAM_WORD_ADDR_WIDTH'(random_seed) | 1'b1),

      .enable  (rng_enable),
      .data_out(rng_word_addr)
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

      .enable  (rng_enable),
      .data_out(rng_data)
  );

  wire mode = random_seed[0];
  wire [1:0] access_offset = rng_data[7:6] ^ rng_word_addr[4:3] ^ count[1:0];
  wire [ADDR_WIDTH-1:0] test_addr = mode ?
      ADDR_BASE | {{ADDR_ZEROS{1'b0}}, rng_word_addr, access_offset} :
      ADDR_BASE | {{ADDR_ZEROS{1'b0}}, access_offset, rng_word_addr};

  // address and data output
  always_comb begin
    wb_adr_o = '0;
    wb_dat_o = '0;
    data_expected = '0;

    case (state)
      ST_WRITE, ST_WRITE_ACTION: begin
        wb_adr_o = test_addr;
        wb_dat_o = rng_data & data_mask;
      end

      ST_READ, ST_READ_ACTION: begin
        wb_adr_o = test_addr;
        data_expected = rng_data & data_mask;
      end

      default: begin
        wb_adr_o = '0;
        wb_dat_o = '0;
        data_expected = '0;
      end
    endcase
  end

  // data mask
  genvar i;
  for (i = 0; i < DATA_WIDTH / 8; i = i + 1) begin : gen_compare
    assign data_mask[i*8+:8] = wb_sel_o[i] ? 8'hFF : 8'h00;
    assign read_compare[i] = ~wb_sel_o[i] ? 1'b1 : (wb_dat_i[i*8+:8] == data_expected[i*8+:8]);
  end

  // wishbone bus
  assign wb_cyc_o = wb_stb_o;

  always_comb begin
    wb_we_o = (state == ST_WRITE_ACTION);
    wb_stb_o = (state == ST_READ_ACTION || state == ST_WRITE_ACTION);
  end

  always_comb begin
    case (rng_data[3:1])
      3'b000: wb_sel_o = 4'b1111;  // full word
      3'b001: wb_sel_o = 4'b1000;  // byte
      3'b010: wb_sel_o = 4'b1111;  // full word
      3'b011: wb_sel_o = 4'b0011;  // half word
      3'b100: wb_sel_o = 4'b0001;  // byte
      3'b101: wb_sel_o = 4'b0100;  // byte
      3'b110: wb_sel_o = 4'b1100;  // half word
      3'b111: wb_sel_o = 4'b0010;  // byte
    endcase
    if (!mode) begin
      wb_sel_o = 4'b0000;
      wb_sel_o[wb_adr_o[1:0]] = 1;
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

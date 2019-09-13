`timescale 1ps / 1ps

module clock (
    output clk_50M,
    output clk_11M0592,
    output clk_125M,
    output clk_125M_90deg
);

reg clk_50M = 0, clk_11M0592 = 0, clk_125M = 0, clk_125M_90deg = 0;

always #(90422/2) clk_11M0592 = ~clk_11M0592;
always #(20000/2) clk_50M = ~clk_50M;
always #(8000/2) clk_125M = ~clk_125M;

initial begin
    #2000;
    forever clk_125M_90deg = #(8000/2) ~clk_125M_90deg;
end

endmodule

`timescale 1ns / 1ps
module rgmii_model (
    input clk_125M,
    input clk_125M_90deg,

    output [3:0] rgmii_rd,
    output rgmii_rx_ctl,
    output rgmii_rxc
);
    logic packet_clk;
    logic trans;
    logic [7:0] count;
    logic [3:0] data1;
    logic [3:0] data2;
    logic [7:0] example [2000:0];
    integer fd, index, res;

    initial begin
        packet_clk = 0;
        fd = $fopen("example_frame.mem", "r");
        index = 0;
        res = 1;
        while (!$feof(fd) && res) begin
            res = $fscanf(fd, "%x", example[index]);
            index = index + 1;
        end
    end

    always packet_clk = #1000 ~packet_clk;

    always_ff @ (posedge clk_125M) begin
        count <= packet_clk ? count + 1 : 0;
        if (packet_clk && count < index - 1) begin
            trans <= 1'b1;
            data1 <= example[count][3:0];
            data2 <= example[count][7:4];
        end else begin
            trans <= 1'b0;
            data1 <= 4'b0;
            data2 <= 4'b0;
        end
    end

    genvar i;
    for (i = 0;i < 4;i++) begin
        ODDR #(
            .DDR_CLK_EDGE("SAME_EDGE")
        ) oddr_inst (
            .D1(data1[i]),
            .D2(data2[i]),
            .C(clk_125M),
            .CE(1'b1),
            .Q(rgmii_rd[i]),
            .R(1'b0)
        );
    end

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE")
    ) oddr_inst_ctl (
        .D1(trans),
        .D2(trans),
        .C(clk_125M),
        .CE(1'b1),
        .Q(rgmii_rx_ctl),
        .R(1'b0)
    );

    assign rgmii_rxc = clk_125M_90deg;
endmodule

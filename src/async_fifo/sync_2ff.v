module sync_2ff #(
    parameter integer WIDTH = 8
)(
    input wire clk_dst,
    input wire rst_n,
    input wire [WIDTH-1:0] din,
    output reg [WIDTH-1:0] sync_dout
);
    reg [WIDTH-1:0] sync_reg;

    always @(posedge clk_dst) begin
        if (!rst_n) begin
            sync_reg <= 0;
            sync_dout <= 0;
        end else begin
            sync_reg <= din;
            sync_dout <= sync_reg;
        end
    end

endmodule
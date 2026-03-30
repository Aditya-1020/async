module sync_3ff #(
    parameter integer WIDTH = 8
)(
    input wire clk_dst,
    input wire rst_n,
    input wire [WIDTH-1:0] din,
    output reg [WIDTH-1:0] sync_dout
);
    reg [WIDTH-1:0] sync_reg1;
    reg [WIDTH-1:0] sync_reg2;

    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg1 <= 0;
            sync_reg2 <= 0;
            sync_dout <= 0;
        end else begin
            sync_reg1 <= din;
            sync_reg2 <= sync_reg1;
            sync_dout <= sync_reg2;
        end
    end

endmodule
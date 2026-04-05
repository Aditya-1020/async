// temp solution for formal 
module fifo_sram_16x64_pdp #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 6
)(
    input  clk0, csb0, web0,
    input  [ADDR_WIDTH-1:0] addr0,
    input  [DATA_WIDTH-1:0] din0,
    output [DATA_WIDTH-1:0] dout0,
    input  clk1, csb1,
    input  [ADDR_WIDTH-1:0] addr1,
    output [DATA_WIDTH-1:0] dout1
);
    assign dout0 = {DATA_WIDTH{1'b0}};
    assign dout1 = {DATA_WIDTH{1'b0}};
endmodule
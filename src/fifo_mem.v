module fifo_mem #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_WIDTH = 6
)(
    // write port
    input wire wr_clk,
    input wire rd_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    
    // read port
    input wire rd_clk,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [DATA_WIDTH-1:0] rd_data
);

    wire csb0_int, web0_int, csb1_int;
    assign csb0_int = ~wr_en;
    assign web0_int = 1'b0; // permanently wr_en
    assign csb1_int = ~rd_en; // deselct when no reads
    wire [15:0] dout0_nc; // unused

    fifo_sram_16x64_pdp u_sram (
    `ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
    `endif
        // Port 0: RW (write side)
        .clk0(wr_clk),
        .csb0(csb0_int),
        .web0(web0_int),
        .addr0(wr_addr),
        .din0(wr_data),
        .dout0(dout0_nc),
        
        // Port 1: read
        .clk1(rd_clk),
        .csb1(csb1_int),
        .addr1(rd_addr),
        .dout1(rd_data)
    );

endmodule
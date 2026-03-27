module async_fifo_2ff #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
)(
    // write side
    input wire wr_clk,
    input wire wr_rst_n,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output wire full, // computed in wr_clk
    output wire overflow,

    // read side
    input wire rd_clk,
    input wire rd_rst_n,
    input wire rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire empty, // computed in rd_clk
    output wire underflow
);
    localparam int PTR_WIDTH = ADDR_WIDTH + 1; // extra bit for full/empty distinction
    localparam int DEPTH = 1 << ADDR_WIDTH;

    reg [PTR_WIDTH-1:0] wr_ptr_b, rd_ptr_b; // binary
    wire [PTR_WIDTH-1:0] wr_ptr_g, rd_ptr_g;  // gray
    reg [PTR_WIDTH-1:0] wr_ptr_g_sync, rd_ptr_g_sync; // synchronized gry pointers

    assign wr_ptr_g = (wr_ptr_b >> 1) ^ wr_ptr_b;
    assign rd_ptr_g = (rd_ptr_b >> 1) ^ rd_ptr_b;

    sync_2ff #(.WIDTH(PTR_WIDTH)) sync_wr2rd_ff (
        .clk_dst(rd_clk),
        .rst_n(rd_rst_n),
        .din(wr_ptr_g),
        .sync_dout(wr_ptr_g_sync)
    );
    
    sync_2ff #(.WIDTH(PTR_WIDTH)) sync_rd2wr_ff (
        .clk_dst(wr_clk),
        .rst_n(wr_rst_n),
        .din(rd_ptr_g),
        .sync_dout(rd_ptr_g_sync)
    );

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) fifo_memory_inst (
        .wr_clk(wr_clk),
        .wr_en(wr_en && !full),
        .wr_data(wr_data),
        .wr_addr(wr_ptr_b[ADDR_WIDTH-1:0]),
        .rd_addr(rd_ptr_b[ADDR_WIDTH-1:0]),
        .rd_data(rd_data)
    );
    
    // write pointer
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_b <= 0;
        end else if (wr_en && !full) begin
            wr_ptr_b <= wr_ptr_b + 1'b1;
        end
    end

    // read pointer
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_b <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr_b <= rd_ptr_b + 1'b1;
        end
    end

    assign full = (wr_ptr_g == {~rd_ptr_g_sync[PTR_WIDTH-1:PTR_WIDTH-2], rd_ptr_g_sync[PTR_WIDTH-3:0]});
    assign empty = (wr_ptr_g_sync == rd_ptr_g);
    assign overflow = wr_en && full;
    assign underflow = rd_en && empty;

endmodule

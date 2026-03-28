module sync_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire full,
    output wire empty,
    output wire overflow,
    output wire underflow
);
    localparam integer ADDR_WIDTH = $clog2(DEPTH);
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1; // extra bit for flag detects

    reg [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    
    // write
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {PTR_WIDTH{1'b0}};
        end else if (wr_en && !full) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= {PTR_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_fifo_mem (
        .wr_clk(clk),
        .wr_en(wr_en && !full),
        .wr_addr(wr_ptr[ADDR_WIDTH-1:0]),
        .wr_data(wr_data),
        .rd_addr(rd_ptr[ADDR_WIDTH-1:0]),
        .rd_data(rd_data)
    );
    
    assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign empty = (wr_ptr == rd_ptr);
    assign overflow = wr_en && full;
    assign underflow = rd_en && empty;

endmodule

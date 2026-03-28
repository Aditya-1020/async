module async_fifo_2ff #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ADDR_WIDTH = 4
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
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1; // extra bit for full/empty distinction
    localparam integer DEPTH = 1 << ADDR_WIDTH;
    localparam integer RST_NUM_STAGES = 2;

    wire wr_rst_n_sync, rd_rst_n_sync;
    reg [PTR_WIDTH-1:0] wr_ptr_b, rd_ptr_b; // binary
    wire [PTR_WIDTH-1:0] wr_ptr_g, rd_ptr_g;  // gray
    reg [PTR_WIDTH-1:0] wr_ptr_g_sync, rd_ptr_g_sync; // synchronized gry pointers
    
    assign wr_ptr_g = (wr_ptr_b >> 1) ^ wr_ptr_b;
    assign rd_ptr_g = (rd_ptr_b >> 1) ^ rd_ptr_b;

    // reset synchronizers
    rst_sync #(.NUM_STAGES(RST_NUM_STAGES)) rst_sync_wr (
        .clk_dst(wr_clk),
        .rst_n(wr_rst_n),
        .sync_rst_n_out(wr_rst_n_sync)
    );
    rst_sync #(.NUM_STAGES(RST_NUM_STAGES)) rst_sync_rd (
        .clk_dst(rd_clk),
        .rst_n(rd_rst_n),
        .sync_rst_n_out(rd_rst_n_sync)
    );
    
    // pointer synchronizers
    sync_2ff #(.WIDTH(PTR_WIDTH)) sync_wr2rd_ff (
        .clk_dst(rd_clk),
        .rst_n(rd_rst_n_sync),
        .din(wr_ptr_g),
        .sync_dout(wr_ptr_g_sync)
    );
    
    sync_2ff #(.WIDTH(PTR_WIDTH)) sync_rd2wr_ff (
        .clk_dst(wr_clk),
        .rst_n(wr_rst_n_sync),
        .din(rd_ptr_g),
        .sync_dout(rd_ptr_g_sync)
    );

    // memory bank
    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) fifo_memory_inst (
        .wr_clk(wr_clk),
        .wr_en(wr_en && !full),
        .wr_data(wr_data),
        .wr_addr(wr_ptr_b[ADDR_WIDTH-1:0]),
        .rd_addr(rd_ptr_b[ADDR_WIDTH-1:0]),
        .rd_data(rd_data)
    );
    
    // write pointer
    always @(posedge wr_clk or negedge wr_rst_n_sync) begin
        if (!wr_rst_n_sync) begin
            wr_ptr_b <= 0;
        end else if (wr_en && !full) begin
            wr_ptr_b <= wr_ptr_b + 1'b1;
        end
    end

    // read pointer
    always @(posedge rd_clk or negedge rd_rst_n_sync) begin
        if (!rd_rst_n_sync) begin
            rd_ptr_b <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr_b <= rd_ptr_b + 1'b1;
        end
    end

    assign full = (wr_ptr_g == {~rd_ptr_g_sync[PTR_WIDTH-1:PTR_WIDTH-2], rd_ptr_g_sync[PTR_WIDTH-3:0]});
    assign empty = (wr_ptr_g_sync == rd_ptr_g);
    assign overflow = wr_en && full;
    assign underflow = rd_en && empty;

    `ifdef FORMAL
        initial begin
            assume(!wr_rst_n);
            assume(!rd_rst_n);
        end

        // reset
        always @(posedge wr_clk) begin
            if (!wr_rst_n) begin
                assert(wr_ptr_b == 0);
            end
        end

        always @(posedge rd_clk) begin
            if (!rd_rst_n) begin
                assert(rd_ptr_b == 0);
            end
        end

        always @(posedge wr_clk) begin
            if (!wr_rst_n) begin
                assert(!wr_rst_n_sync);
            end
        end

        always @(posedge wr_clk) begin
            if (!rd_rst_n) begin
                assert(!rd_rst_n_sync);
            end
        end

        // full check
        always @(posedge wr_clk) begin
            if (full) begin
                assert((wr_ptr_g == {~rd_ptr_g_sync[PTR_WIDTH-1:PTR_WIDTH-2], rd_ptr_g_sync[PTR_WIDTH-3:0]}));
            end
        end
        // empty check
        always @(posedge rd_clk) begin
            if (empty) begin
                assert((wr_ptr_g_sync == rd_ptr_g));
            end
        end
        
        // overflow
        always @(posedge wr_clk) begin
            if (overflow) begin
                assert(full);
            end
        end

        // underflow
        always @(posedge rd_clk) begin
            if (underflow) begin
                assert(empty);
            end
        end

    `endif

endmodule

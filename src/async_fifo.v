module async_fifo (
    // write side
    input wire wr_clk,
    input wire wr_rst_n,
    input wire wr_en,
    input wire [15:0] wr_data,
    output wire full,
    output wire overflow,

    // read side
    input wire rd_clk,
    input wire rd_rst_n,
    input wire rd_en,
    output wire [15:0] rd_data,
    output wire empty,
    output wire underflow
);
    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 6; // 64 entries
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1; // extra bit for full/empty distinction
    localparam integer RST_NUM_STAGES = 2;

    generate
        if (DATA_WIDTH != 16) begin : g_dw
            initial $fatal(1, "DATA_WIDTH must be 16");
        end

        if (ADDR_WIDTH != 6) begin : g_aw
            initial $fatal(1, "ADDR_WIDTH must be 6");
        end

        if (PTR_WIDTH != ADDR_WIDTH + 1) begin : g_pw
            initial $fatal(1, "PTR_WIDTH must be ADDR_WIDTH+1");
        end

        if (RST_NUM_STAGES != 2) begin : g_rst
            initial $fatal(1, "RST_NUM_STAGES must be 2");
        end
    endgenerate

    // internal signals
    wire wr_rst_n_sync, rd_rst_n_sync;

    wire [PTR_WIDTH-1:0] wr_ptr_b, rd_ptr_b; // binary
    wire [PTR_WIDTH-1:0] wr_ptr_g, rd_ptr_g;  // gray
    wire [PTR_WIDTH-1:0] wr_ptr_g_sync, rd_ptr_g_sync; // synchronized gry pointers
    
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
    
    // pointer synchronizers (2FF)
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

    // write pointer
    ptr_inc #(.PTR_WIDTH(PTR_WIDTH)) wr_ptr_inc (
        .i_clk(wr_clk),
        .i_rst_n(wr_rst_n_sync),
        .i_en_flag_active(wr_fire),
        .o_ptr(wr_ptr_b)
    );
    
    // read pointer
    ptr_inc #(.PTR_WIDTH(PTR_WIDTH)) rd_ptr_inc (
        .i_clk(rd_clk),
        .i_rst_n(rd_rst_n_sync),
        .i_en_flag_active(rd_fire),
        .o_ptr(rd_ptr_b)
    );

    // sram read address pre-fetching
    reg [ADDR_WIDTH-1:0] rd_addr_r;

    always @(posedge rd_clk) begin
        if (!rd_rst_n_sync) begin
            rd_addr_r <= {ADDR_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin // data is ready one cycle laeter
            rd_addr_r <= rd_ptr_b[ADDR_WIDTH-1:0] + 1'b1;
        end else begin
            rd_addr_r <= rd_addr_r;
        end
    end

    // sram instantce
    fifo_mem  #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) sram_inst (
        // write port
        .wr_clk(wr_clk),
        .wr_en(wr_en && !full),
        .wr_addr(wr_ptr_b[ADDR_WIDTH-1:0]),
        .wr_data(wr_data),
        
        
        // read port
        .rd_clk(rd_clk),
        .rd_en(!empty), // active whenever data exists
        .rd_addr(rd_addr_r),
        .rd_data(rd_data)
    );
    
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

        // cover
        always @(posedge wr_clk) begin
            if (wr_en && !full) begin
                cover(wr_ptr_b == (1<<ADDR_WIDTH)-1);
            end
        end

        always @(posedge rd_clk) begin
            if (rd_en && !empty) begin
                cover(rd_ptr_b == (1<<ADDR_WIDTH)-1);
            end
        end

    `endif

endmodule

module rst_sync #(
    parameter integer NUM_STAGES = 2
)(
    input wire clk_dst,
    input wire rst_n,
    output wire sync_rst_n_out
);
    reg [NUM_STAGES-1:0] sync_reg;

    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg <= {NUM_STAGES{1'b0}};
        end else begin
            sync_reg <= {sync_reg[NUM_STAGES-2:0], ~1'b0};
        end
    end

    assign sync_rst_n_out = sync_reg[NUM_STAGES-1];

endmodule
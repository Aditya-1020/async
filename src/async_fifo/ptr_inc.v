module ptr_inc #(
    parameter integer PTR_WIDTH = 5
)(
    input wire i_clk,
    input wire i_rst_n,
    input wire i_en_flag_active,
    output reg [PTR_WIDTH-1:0] o_ptr
);
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_ptr <= {PTR_WIDTH{1'b0}};
        end else if (i_en_flag_active) begin
            o_ptr <= o_ptr + 1'b1;
        end
    end

endmodule
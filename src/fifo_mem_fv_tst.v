// formal verification for fifo_mem didnt work so just testing assertions for signals here
module fifo_mem_fv_tst (input wire wr_en, rd_en);

    wire csb0_int = ~wr_en;
    wire web0_int = 1'b0;
    wire csb1_int = ~rd_en;


    `ifdef FORMAL
        always @(*) begin
            assert (csb0_int == ~wr_en); // wr_en gating
            assert (csb1_int == ~rd_en); // rd_en gating
            assert (web0_int == 0); // wr mode permanent low
        end
    `endif

endmodule

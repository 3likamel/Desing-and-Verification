module strt_check (
    input 		clk, rst,
    input 		[4:0] edge_cnt,
    input 		[4:0] f_edge,
    input 		strt_chk_en, sampled_bit,
    output reg  strt_glitch
);

always_ff @(posedge clk or negedge rst) begin
    if (~rst) begin
        strt_glitch <= 1'b0;
    end else begin
        if (strt_chk_en) begin
            if (edge_cnt == f_edge - 1) begin
                if (sampled_bit == 1'b1) begin
                    strt_glitch <= 1'b1;
                end else begin
                    strt_glitch <= 1'b0;
                end
            end else begin
                strt_glitch <= 1'b0;
            end
        end else begin
            strt_glitch <= 1'b0;
        end
    end
end

endmodule

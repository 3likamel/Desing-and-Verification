module parity_check (
    input 		clk, rst,
    input 		[7:0] P_DATA,
    input 		[4:0] edge_cnt,
    input 		[4:0] f_edge,
    input 		PAR_TYP, par_chk_en, sampled_bit,
    output reg  par_err
);

wire parity;
assign parity = ^P_DATA;
always_ff @(posedge clk or negedge rst) begin
    if (~rst) begin
        par_err <= 1'b0;
    end else begin
        if (par_chk_en) begin
            if (edge_cnt ==  f_edge - 1) begin
                if (PAR_TYP == 1'b0 && ((sampled_bit != parity))) begin   /// 11110000 parity = 0 and we want even so added bit will be 0
                    par_err <= 1'b1;
                end else if (PAR_TYP == 1'b1 && ((sampled_bit == parity))) begin // 11100000 parity will be 1 and sampled bit will be 0
                    par_err <= 1'b1;
                end else begin
                    par_err <= 1'b0;
                end
            end
        end else begin
            par_err <= 1'b0;
        end
    end
end

endmodule

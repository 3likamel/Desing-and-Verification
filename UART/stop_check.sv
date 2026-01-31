module stp_check (
    input 				clk, rst,
    input 				[4:0] edge_cnt,
    input 				[4:0] f_edge,
    input 				stp_chk_en, sampled_bit,
    output reg 			stp_err
);

always_ff @(posedge clk or negedge rst) begin
    if (~rst) begin
        stp_err <= 1'b0;
    end else begin
        if (stp_chk_en) begin
            if (edge_cnt == f_edge - 1) begin
                if (sampled_bit == 1'b0) begin
                    stp_err <= 1'b1;
                end else begin
                    stp_err <= 1'b0;
                end
            end else begin
                stp_err <= 1'b0;
            end
        end else begin
            stp_err <= 1'b0;
        end
    end
end

endmodule


module deserializer (
    input 		clk, rst,
    input 		deser_en, sampled_bit,
    input 		[3:0] bit_cnt,
    output reg  [7:0] P_DATA
);

always_ff @(posedge clk or negedge rst) begin 
    if (~rst) begin
        P_DATA <= 8'b0;
    end else begin
        if (deser_en) begin
            P_DATA[bit_cnt - 1] <= sampled_bit;
        end
    end
end

endmodule

module edge_bite_counter (
    input 		clk, rst,
    input 		enable,
    input 		PAR_EN,
    input 		[5:0] Prescale,
    output reg  [4:0] edge_cnt,
    output reg  [3:0] bit_cnt,
    output reg  [4:0] f_edge
   
);


always_ff @(posedge clk or negedge rst) begin 
    if (~rst) begin
        edge_cnt <= 5'b0;
        bit_cnt  <= 4'b0;
        f_edge     <= 5'b11111;
    end else begin
        if (enable) begin
            case (Prescale)
                6'b000100: begin
                	f_edge     <= 5'b00011;
                    if (edge_cnt == f_edge) begin
                        edge_cnt <= 5'b0;
                        bit_cnt  <= bit_cnt + 1;
                        if (bit_cnt == 'b1010)
                        	bit_cnt <= 'b0;
                    end else begin
                        edge_cnt <= edge_cnt + 1;
                    end
                end
                6'b001000: begin
                	f_edge     <= 5'b00111;
                    if (edge_cnt == f_edge) begin
                        edge_cnt <= 5'b0;
                        bit_cnt  <= bit_cnt + 1;
                        if (bit_cnt == 'b1010)
                        	bit_cnt <= 'b0;
                    end else begin
                        edge_cnt <= edge_cnt + 1;
                    end
                end
                6'b010000: begin
                	f_edge     <= 5'b01111;
                    if (edge_cnt == f_edge) begin
                        edge_cnt <= 5'b0;
                        bit_cnt  <= bit_cnt + 1;
                        if (bit_cnt == 'b1010)
                        	bit_cnt <= 'b0;
                    end else begin
                        edge_cnt <= edge_cnt + 1;
                    end
                end
                6'b100000: begin
                	f_edge     <= 5'b11111;
                    if (edge_cnt == f_edge) begin
                        edge_cnt <= 5'b0;
                        bit_cnt  <= bit_cnt + 1;
                        if (bit_cnt == 'b1010)
                        	bit_cnt <= 'b0;
                    end else begin
                        edge_cnt <= edge_cnt + 1;
                    end
                end
                default: begin
                    edge_cnt <= 5'b0;
                    bit_cnt  <= 4'b0;
                    f_edge     <= 5'b11111;
                end
            endcase
        end else begin
        	edge_cnt <= 'b0;
        	bit_cnt  <= 'b0;
        	f_edge     <= 5'b11111;
        end
    end
end

endmodule

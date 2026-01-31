module data_sampling (
    input 		clk, rst,
    input 		RX_IN,
    input 		data_samp_en,
    input 		[5:0] Prescale,
    input 		[4:0] edge_cnt,
    output wire sampled_bit
);
    reg [3:0] samples;

    always_ff @(posedge clk or negedge rst) begin
        if (~rst) begin
            samples <= 3'b0;
        end else if (data_samp_en) begin
            case (Prescale)
                6'b000100: begin
                    case (edge_cnt)
                        5'b00000: samples[0] <= RX_IN;
                        5'b00001: samples[1] <= RX_IN;
                        5'b00010: samples[2] <= RX_IN;
                        default: samples <= samples;
                    endcase
                end
                6'b001000: begin
                    case (edge_cnt)
                        5'b00011: samples[0] <= RX_IN;
                        5'b00100: samples[1] <= RX_IN;
                        5'b00101: samples[2] <= RX_IN;
                        default: samples <= samples;
                    endcase
                end
                6'b010000: begin
                	case (edge_cnt)
                        5'b00111: samples[0] <= RX_IN;
                        5'b01000: samples[1] <= RX_IN;
                        5'b01001: samples[2] <= RX_IN;
                        default: samples <= samples;
                    endcase
                end
                6'b100000: begin
                	case (edge_cnt)
                        5'b01111: samples[0] <= RX_IN;
                        5'b10000: samples[1] <= RX_IN;
                        5'b10001: samples[2] <= RX_IN;
                        default: samples <= samples;
                    endcase
                end
                default: samples <= 3'b0;
            endcase
        end else begin
            samples <= 3'b0;
        end
    end
      assign sampled_bit = (samples[0]&samples[1]) | (samples[1]&samples[2]) | (samples[0]&samples[3]);

endmodule

module MUX (
	input wire [1:0] mux_sel,
	input wire start_bit,
	input wire stop_bit,
	input wire ser_data,
	input wire par_bit,
	input wire CLK,RST, // @suppress "Port 'CLK' is never used locally" // @suppress "Port 'RST' is never used locally"
	output reg TX_OUT
);

always_comb 
begin
		case (mux_sel)
			2'b00:
			begin
				TX_OUT  = start_bit;
			end
			2'b01:
			begin
				TX_OUT  = stop_bit;
			end
			2'b10:
			begin
				TX_OUT  = ser_data;
			end
			2'b11:
			begin
				TX_OUT  = par_bit;
			end
			default:
			begin
				TX_OUT  = stop_bit;
			end
		endcase  
end
endmodule
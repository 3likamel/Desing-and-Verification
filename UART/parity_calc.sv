module parity_calc #(parameter Data_WD = 8)
(
	input  wire	[Data_WD-1 : 0]		P_DATA,
	input  wire						Data_Valid,
	input  wire						PAR_TYP,
	input  wire 					CLK,RST,
	output reg						par_bit
);

wire parity;
reg  [Data_WD-1 : 0] s_data;

assign parity = ^s_data;

always_ff @(posedge CLK or negedge RST) begin 
	if(~RST) begin
		s_data  <= 'b0;
	end else if (Data_Valid) begin
		s_data <= P_DATA;
	end
end

always_ff @(posedge CLK) begin 
	if (PAR_TYP) 
	begin
		if (parity) 
			begin
				par_bit <= 1'b0;
			end
		else
			begin
				par_bit <= 1'b1;
			end
	end 
	else
	begin
		 if (parity) 
		 	begin
		 		par_bit <= 1'b1;
		 	end
		 else
		 	begin
		 		par_bit <= 1'b0;
		 	end
	end
end

endmodule
module DFF (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input d,
	output reg q
);

logic temp;

always_ff @(posedge clk or negedge rst_n) begin : proc_q
	if(~rst_n) begin
		temp <= 0;
	end else begin
		temp <= d;
	end
end

assign q = temp;

endmodule : DFF
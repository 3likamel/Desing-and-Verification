module UART_TX #(parameter Data_WD = 8)
(
	input  wire	[Data_WD-1 : 0]		P_DATA,
	input  wire						Data_Valid,
	input  wire						PAR_EN,
	input  wire						PAR_TYP,
	input  wire						start_bit,
	input  wire						stop_bit,
	input  wire						CLK,RST,
	output wire						TX_OUT,
	output wire						busy
);

wire [1:0] mux_sel;
wire ser_en;
wire ser_done;
wire ser_data;
wire par_bit;

serializer #(.Data_WD(Data_WD)) SUT 
(
	.P_DATA     (P_DATA),
	.Data_Valid (Data_Valid),
	.ser_en 	(ser_en),
	.ser_done   (ser_done),
	.ser_data   (ser_data),
	.CLK 		(CLK),
	.RST 		(RST)
);

FSM	FUT (
	.Data_Valid	(Data_Valid),
	.busy       (busy),
	.PAR_EN     (PAR_EN),
	.ser_en     (ser_en),
	.ser_done   (ser_done),
	.mux_sel    (mux_sel),
	.CLK        (CLK),
	.RST        (RST)
);

parity_calc #(.Data_WD(Data_WD)) PUT 
(
	.Data_Valid (Data_Valid),
	.P_DATA 	(P_DATA),
	.PAR_TYP 	(PAR_TYP),
	.par_bit 	(par_bit),
	.CLK 		(CLK),
	.RST 		(RST)
);

MUX MUT (
	.mux_sel  (mux_sel),
	.start_bit(start_bit),
	.stop_bit (stop_bit),
	.ser_data (ser_data),
	.par_bit  (par_bit),
	.TX_OUT   (TX_OUT),
	.CLK      (CLK),
	.RST      (RST)
);

endmodule

module UART_RX (
    input 		clk, rst,
    input 		RX_IN,
    input 		[5:0] Prescale,
    input 		PAR_EN, PAR_TYP,
    output wire stp_err, par_err,
    output wire [7:0] P_DATA,
    output wire data_valid
);

wire str_glitch;
wire sampled_bit;
wire [3:0] bit_cnt;
wire [4:0] edge_cnt;
wire data_samp_en, deser_en, par_chk_en, str_chk_en, stp_chk_en, enable;
wire [4:0] f_edge;

FSM FUT (
    .clk(clk),
    .rst(rst),
    .RX_IN(RX_IN),
    .PAR_EN(PAR_EN),
    .bit_cnt(bit_cnt),
    .edge_cnt(edge_cnt),
    .f_edge      (f_edge),
    .par_err(par_err),
    .str_glitch(str_glitch),
    .stp_err(stp_err),
    .data_samp_en(data_samp_en),
    .deser_en(deser_en),
    .par_chk_en(par_chk_en),
    .str_chk_en(str_chk_en),
    .stp_chk_en(stp_chk_en),
    .enable(enable),
    .data_valid(data_valid)
);

edge_bite_counter CUO (
    .clk(clk),
    .rst(rst),
    .Prescale(Prescale),
    .enable(enable),
    .PAR_EN  (PAR_EN),
    .edge_cnt(edge_cnt),
    .f_edge  (f_edge),
    .bit_cnt(bit_cnt)
);

parity_check PC (
    .clk(clk),
    .rst(rst),
    .P_DATA     (P_DATA),
    .edge_cnt(edge_cnt),
    .f_edge     (f_edge),
    .PAR_TYP(PAR_TYP),
    .par_chk_en(par_chk_en),
    .sampled_bit(sampled_bit),
    .par_err(par_err)
);

deserializer DES (
    .clk(clk),
    .rst(rst),
    .deser_en(deser_en),
    .sampled_bit(sampled_bit),
    .bit_cnt(bit_cnt),
    .P_DATA(P_DATA)
);

data_sampling DS (
    .clk(clk),
    .rst(rst),
    .RX_IN(RX_IN),
    .Prescale(Prescale),
    .data_samp_en(data_samp_en),
    .edge_cnt(edge_cnt),
    .sampled_bit(sampled_bit)
);

strt_check strt_check_inst (
    .clk(clk),
    .rst(rst),
    .edge_cnt(edge_cnt),
    .f_edge     (f_edge),
    .strt_chk_en(str_chk_en),
    .sampled_bit(sampled_bit),
    .strt_glitch(str_glitch)
);

stp_check SPC (
    .clk(clk),
    .rst(rst),
    .edge_cnt(edge_cnt),
    .f_edge  (f_edge),
    .stp_chk_en(stp_chk_en),
    .sampled_bit(sampled_bit),
    .stp_err(stp_err)
);

endmodule


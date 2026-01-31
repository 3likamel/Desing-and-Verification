module FSM (
    input       clk, rst,
    input       RX_IN, PAR_EN,
    input       [3:0] bit_cnt,
    input       [4:0] edge_cnt,
    input       [4:0] f_edge,
    input       par_err, str_glitch, stp_err,
    output reg  data_samp_en, deser_en, par_chk_en, str_chk_en, stp_chk_en,
    output reg  enable, 
    output reg  data_valid
);
reg par_ok;
reg stp_ok;
typedef enum logic [2:0] {
    idle = 3'b000,
    start = 3'b001,
    deserializer = 3'b010,
    parity = 3'b011,
    stop = 3'b100
} _state;

_state cu_state, nx_state;

always_ff @(posedge clk or negedge rst) begin
    if (~rst)
        cu_state <= idle;
    else if (cu_state == idle && ~RX_IN) begin
        cu_state <= start;
    end
    else
        cu_state <= nx_state;
        
end

always_comb begin
    nx_state = cu_state;

    case (cu_state)

        idle: begin
            if (!RX_IN)
                nx_state = start;
        end

        start: begin
            if (edge_cnt == f_edge) begin
                if (str_glitch)
                    nx_state = idle;
                else
                    nx_state = deserializer;
            end
        end

        deserializer: begin
            if ((bit_cnt == 4'd8) && (edge_cnt == f_edge)) begin
                if (PAR_EN)
                    nx_state = parity;
                else
                    nx_state = stop;
            end
        end

        parity: begin
            if (edge_cnt == f_edge)
                nx_state = stop;
        end

        stop: begin
            if (edge_cnt == f_edge) begin
                nx_state = idle;
            end
        end

        default: nx_state = idle;
    endcase
end


always_comb begin
    data_samp_en = 1'b0;
    deser_en     = 1'b0;
    par_chk_en   = 1'b0;
    str_chk_en   = 1'b0; 
    stp_chk_en   = 1'b0;
    enable       = 1'b0;
    data_valid   = 0;
    case (cu_state)
        idle: begin
            data_samp_en = 1'b1;
            enable       = 1'b0;
            par_ok       = 0;
            stp_ok       = 0; 
            
        end
        start: begin
            str_chk_en   = 1'b1;
            data_samp_en = 1'b1;
            enable       = 1'b1;
            par_ok       = 0;
            stp_ok       = 0; 
        end
        deserializer: begin
            deser_en     = 1'b1;
            data_samp_en = 1'b1;
            enable       = 1'b1;
            par_ok       = 0;
            stp_ok       = 0; 
        end
        parity: begin
            par_chk_en   = 1'b1;
            data_samp_en = 1'b1;
            enable       = 1'b1;
            par_ok       = par_err;
            stp_ok       = 0; 
        end
        stop: begin
            stp_chk_en   = 1'b1;
            data_samp_en = 1'b1;
            enable       = 1'b1;
            par_ok       = par_ok;
            stp_ok       = stp_err; 
            if (PAR_EN && (edge_cnt == f_edge))
                data_valid = !(par_ok & stp_ok);
            else if (edge_cnt == f_edge)
                data_valid = !stp_ok;
            
        end
        default: begin
            data_samp_en = 1'b0;
            deser_en     = 1'b0;
            par_chk_en   = 1'b0;
            str_chk_en   = 1'b0; 
            stp_chk_en   = 1'b0;
            enable       = 1'b0;
            par_ok       = 0;
            stp_ok       = 0; 
        end
    endcase
end


endmodule

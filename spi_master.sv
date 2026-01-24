module spi_master (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  data_in,
    input  logic        start,
    output logic        sclk,
    output logic        mosi,
    output logic        cs_n
    // output logic        busy,
    // output logic [7:0]  data_out
);

    typedef enum logic [1:0] { IDLE, TRANSFER, DONE } state_t;
    state_t current_state, next_state;

    logic [2:0] clk_div_cnt;
    logic [3:0] bit_cnt;
    logic [7:0] shift_reg;

    // clc k divider for SCLK generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= 5'd0;
            sclk <= 1'b0;
        end else if (current_state == TRANSFER) begin
            if (clk_div_cnt == 3'd4) begin 
                clk_div_cnt <= 3'd0;
                sclk <= ~sclk;
            end else begin
                clk_div_cnt <= clk_div_cnt + 3'd1;
            end
        end else begin
            clk_div_cnt <= 3'd0;
            sclk <= 1'b0;
        end
    end


    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = TRANSFER;
                end
            end
            TRANSFER: begin
                if (bit_cnt == 4'd8 && sclk == 1'b0) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // output logic
    always_comb begin
        case (current_state)
            IDLE: begin
                cs_n = 1'b1;
                mosi = 1'b0;
                bit_cnt = 4'd0;
                if (start) begin
                    shift_reg = data_in;
                end else begin
                    shift_reg = 8'd0;
                end
            end
            TRANSFER: begin
                cs_n = 1'b0;
                if (sclk == 1'b0) begin   // Falling edge: output data
                    mosi = shift_reg[7];
                end else if (sclk == 1'b1) begin
                    shift_reg = {shift_reg[6:0], 1'b0}; // Shift left on rising edge
                    bit_cnt = bit_cnt + 4'd1;
                end
            end
            DONE: begin
                cs_n = 1'b1;
                mosi = 1'b0;
                shift_reg = 8'd0;
                bit_cnt = 4'd0;
            end
            endcase
    end
endmodule




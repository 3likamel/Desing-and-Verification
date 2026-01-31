module i2c_controller#(parameter data_wd = 8, addr_wd = 7) (
    input   wire      clk, rst_n,
    input   wire      ack,
    input   wire      en,
    input   wire      r_w,
    input   wire      [data_wd-1 : 0] wdata,
    input   wire      [addr_wd-1 : 0] addr,
    output  reg       [data_wd-1 : 0] rdata,
    output  reg       done,
    output  reg       scl,
    inout   wire      sda
);

reg rw;
reg sda_out;
reg sda_oe;
reg [data_wd/2 : 0] bit_cnt;

typedef enum reg [3:0] {
    idle,
    start,
    send_addr,
    wait_ack,
    send_data,
    wait_ack2,
    stop_1,
    stop_2
} state_e;

state_e current_state, next_state;


assign sda_oe =  (!r_w || !(current_state == send_data));
assign sda    = sda_oe ? sda_out : 1'bz;
assign scl    = ( current_state == send_addr || current_state == send_data )  ? clk : 1;


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= idle;
    end else begin
        current_state <= next_state;
    end
    
end

always_comb begin
    next_state = current_state;
    case (current_state)
        idle: begin
            if (en) begin
                next_state = start;
            end
        end

        start: begin
            next_state = send_addr;
        end

        send_addr: begin
            if (bit_cnt == addr_wd) begin
                next_state = wait_ack;
            end
        end

        wait_ack: begin
            if (!ack) begin
                next_state = send_data;
            end
        end

        send_data: begin
            if (bit_cnt == data_wd) begin
                next_state = wait_ack2;
            end
        end

        wait_ack2: begin
            if (!ack) begin
                next_state = stop_1;
            end
        end

        stop_1: begin
            next_state = stop_2;
        end

        stop_2: begin
            next_state = idle;
        end

        default: begin
            next_state = idle;
        end

    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_cnt <= 0;
    end else begin
        case (current_state)
            send_addr, send_data: begin
                bit_cnt <= bit_cnt + 1;
            end
            default: begin
                bit_cnt <= 0;
            end
        endcase
    end
end

always_comb begin
    sda_out = 1;
    rdata   = rdata;
    done    = 0;
    rw      = rw;
    case (current_state)
        idle: begin
            sda_out = 1;
            rw     = r_w;
        end

        start: begin
            sda_out = 0;
            rw     = rw;
        end

        send_addr: begin
            sda_out = addr [bit_cnt];
            if (bit_cnt == addr_wd) begin
                sda_out = rw;
            end
        end

        wait_ack: begin
           sda_out = 0;
        end

        send_data: begin
            if (!rw) begin
                sda_out = wdata [bit_cnt];
                if (bit_cnt == data_wd) begin
                    sda_out = 0;
                end
            end else begin
                sda_out = 0;
                rdata   = rdata;
                if (scl) begin
                    rdata[bit_cnt-1] <= sda;
                end
            end
        end

        wait_ack2: begin
            sda_out = 0;            
        end

        stop_1: begin
            sda_out = 0;
        end

        stop_2: begin
            sda_out = 1;
            done    = 1;
        end

        default: begin
            sda_out = 1;
            rdata   = 0;
            done    = 0;
        end

    endcase
end
endmodule





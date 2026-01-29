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

reg sda_out;
reg sda_in;
reg sda_oe;

typedef enum reg [2:0] {
    idle,
    start,
    send_addr,
    send_data,
    stop_1,
    stop_2
} state_e;

state_e state;


assign sda_oe =  (!r_w || !(state == send_data));
assign sda    = sda_oe ? sda_out : sda_in;



// FSM
always_ff @(posedge clk or negedge rst_n) begin

    rdata <= 0;
    done  <= 0;
    scl   <= 1;
    sda_in    <= 1;
    sda_out    <= 1;

    if (!rst_n) begin

        rdata <= 0;
        done  <= 0;
        scl   <= 1;
        sda_in    <= 1;
        sda_out    <= 1;

    end else begin

        case (state) 
            idle: begin

                if (en) begin
                    sda_out   <= 1;
                    scl   <= 1;
                    state <=  start;
                end

            end
            
            start: begin

                sda_out   <= 0;
                scl   <= 1;
                state <= send_addr;

            end

            send_addr: begin

                scl <= clk;

                for (int i = 0; i<addr_wd ; i++) begin
                    sda_out <= addr[i];
                end

                sda_out <= r_w;
                state <= send_data;
                
            end

            send_data : begin
                
                scl <= clk;

                // if ack didn't pulldown we will wait
                if (!ack) begin

                    if (r_w) begin

                        // Receiving data from slave
                        for (int i =0; i<data_wd ; i++) begin
                            rdata [i] <= sda_in;
                        end
                        state <= stop_1;
                    end else begin
                        
                        // Sending data to Slave
                        for (int i =0; i<data_wd ; i++) begin
                            sda_out <= wdata[i];
                        end
                        state <= stop_1;
                    end
                         
                end
            end

            stop_1: begin
                
                // if ack didn't pulldown we will wait
                if(!ack) begin

                    scl <= 1;
                    sda_out  <= 0;

                end
                
            end
            
            stop_2: begin
                
                    scl <= 1;
                    sda_out  <= 1;
                    state <= idle;
                    done<= 1;
            end

            default: begin
                rdata <= 0;
                done  <= 0;
                scl   <= 1;
                sda_in    <= 1;
                sda_out    <= 1;
            end
            
            

        endcase;
            
    end
    
end








endmodule
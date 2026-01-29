module i2c_mem #(parameter data_wd = 8, addr_wd = 7) (
    input  wire clk,
    input  wire rst_n,
    input  wire scl,
    inout  wire sda,
    output reg  ack
);

reg r_w;
reg sda_oe; 
reg sda_out;
reg sda_in;
reg [addr_wd-1 : 0] addr; 
reg [data_wd-1 : 0] wdata; 
reg [data_wd-1 : 0] rdata; 
reg [data_wd-1 : 0] mem [0 : (1<<addr_wd)-1];

typedef enum reg [2:0] {
    start,
    address,
    write_data,
    read_data,
    stop
} state_e ;
state_e state;

assign sda_oe = (state == read_data);
assign sda    = sda_oe ? sda_out : 1'bz;
assign sda_in = sda;

always_ff @(posedge clk or negedge rst_n) begin
    
    addr    <= 0;
    wdata   <= 0;
    rdata   <= 0;
    sda_out <= 0;
    r_w     <= 0;
    state   <= start;
    ack     <= 1;

    if(!rst_n) begin

        addr    <= 0;
        wdata   <= 0;
        rdata   <= 0;
        sda_out <= 0;
        r_w     <= 0;
        state   <= start;
        ack     <= 1;

        for (int i = 0 ; i < (1<<addr_wd) ; i++ ) begin
            mem [i] <= '0;
        end

    end else begin

        case (state)

            start: begin
                
                ack <= 1;

                if (scl && !sda_in)
                    state <= address;
                else
                    state <= start;
            end

            address: begin
                
                for(int i = 0; i < addr_wd; i++) begin
                    addr [i] <= sda_in;
                end

                r_w <= sda_in;

                if (r_w)
                    state <= read_data;
                else
                    state <= write_data;

                ack <= 0;
                
            end
            
            read_data: begin

                ack <= 1;
                rdata <= mem [addr];

                for (int i = 0; i < data_wd; i++)  begin
                    sda_out <= rdata [i];
                end            
                
                state <= stop;
            end

            write_data: begin

                ack <=1;

                for (int i = 0; i < data_wd; i++)  begin
                    wdata[i] <= sda_in;
                end 

                mem [addr] <= wdata;

                state <= stop;

            end
            
            stop: begin

                ack <= 0;
                state <= start;

            end
            
            default: begin
                addr    <= 0;
                wdata   <= 0;
                rdata   <= 0;
                sda_out <= 0;
                r_w     <= 0;
                state   <= start;
                ack     <= 1;
            end
            
            

        endcase;
    end
    
    
end



endmodule

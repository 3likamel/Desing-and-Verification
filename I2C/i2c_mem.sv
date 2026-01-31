module i2c_mem #(parameter data_wd = 8, addr_wd = 7) (
    input  wire clk,
    input  wire rst_n,
    input  wire scl,
    inout  wire sda,
    output wire  ack
);

reg r_w;
reg sda_oe; 
reg sda_out;
reg [data_wd/2 : 0] bit_cnt;
reg [addr_wd-1 : 0] addr; 
reg [data_wd-1 : 0] wdata; 
reg [data_wd-1 : 0] rdata; 
reg [data_wd-1 : 0] mem [0 : (1<<addr_wd)-1];


typedef enum reg [2:0] {
    start,
    address,
    down_ack,
    write_data,
    read_data,
    down_ack2,
    stop
} state_e ;
state_e state;

assign sda_oe = (state == read_data);
assign sda    = sda_oe ? sda_out : 1'bz;

assign ack    = (state == down_ack || state == down_ack2) ? 0 : 1;



always_ff @(posedge clk or negedge rst_n) begin
    
    addr    <= 0;
    wdata   <= 0;
    rdata   <= 0;
    sda_out <= 0;
    r_w     <= 0;
    bit_cnt <= 0;

    if(!rst_n) begin

        addr    <= 0;
        wdata   <= 0;
        rdata   <= 0;
        sda_out <= 0;
        r_w     <= 0;
        state   <= start;
        bit_cnt <= 0;

        for (int i = 0 ; i < (1<<addr_wd) ; i++ ) begin
            mem [i] <= '0;
        end

    end else begin

        case (state)

            start: begin
                

                if (scl && !sda)
                    state <= address;
                else
                    state <= start;
            end

            address: begin

                addr  <=  addr;
                if (bit_cnt == addr_wd) begin

                    r_w <= sda;
                    bit_cnt <= 0;
                    state   <= down_ack;
                    
                end else begin

                    addr [bit_cnt] <= sda;
                    bit_cnt <= bit_cnt + 1;

                end    
                
            end

            down_ack: begin
                r_w    <= r_w;
                addr  <=  addr;
                if (r_w) begin
                    state <= read_data;
                    rdata <= mem [addr];
                end
                else
                    state <= write_data;

            end
            
            read_data: begin
                r_w     <= r_w;
                addr  <=  addr;
                rdata <= rdata;
                
                if (bit_cnt == data_wd) begin
                    bit_cnt <= 0;
                    state   <= down_ack2;
                end else begin
                    
                    sda_out <= rdata [bit_cnt];
                    bit_cnt <= bit_cnt + 1;

                end
                
                
            end

            write_data: begin
                r_w     <= r_w;
                addr  <=  addr;
                wdata <=  wdata;
                if (bit_cnt == data_wd) begin
                    bit_cnt <= 0;
                    state   <= down_ack2;
                    wdata <=  wdata;
                    mem [addr] <= wdata;
                end else begin
                    wdata [bit_cnt] <= sda;
                    bit_cnt <= bit_cnt + 1;
                end

            end

            down_ack2: begin

                state <= stop;

            end
            
            stop: begin

                state <= start;

            end
            
            default: begin
                addr    <= 0;
                wdata   <= 0;
                rdata   <= 0;
                sda_out <= 0;
                r_w     <= 0;
                state   <= start;
                bit_cnt <= 0;
            end
            
            

        endcase;
    end
    
    
end



endmodule

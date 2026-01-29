module I2C #(parameter data_wd = 8, addr_wd = 7) (

    input clk,
    input rst_n,
    input en, r_w,
    input [data_wd-1 : 0] wdata,
    input [addr_wd-1 : 0] addr,
    output [data_wd-1 : 0] rdata,
    output done
    
    );

    wire scl;
    wire sda;
    wire ack;

    i2c_controller #(
        .data_wd(data_wd),
        .addr_wd(addr_wd)
    ) i2c_c (
        .clk(clk),
        .rst_n(rst_n),
        .ack(ack),
        .en(en),
        .r_w(r_w),
        .wdata(wdata),
        .addr(addr),
        .rdata(rdata),
        .done(done),
        .scl(scl),
        .sda(sda)
    );

    i2c_mem #(
        .data_wd(data_wd),
        .addr_wd(addr_wd)
    ) i2c_m (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .ack(ack),
        .sda(sda)
    );
    
endmodule

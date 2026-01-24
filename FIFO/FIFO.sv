module FIFO #(
    parameter int width = 8,
    parameter int dipth = 32
)(
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 rd,
    input  logic                 wr,
    input  logic [width-1:0]     din,
    output logic                 full,
    output logic                 empty,
    output logic [width-1:0]     dout
);

    localparam int addr_width = $clog2(dipth);

    logic [width-1:0] mem [0:dipth-1];
    logic [addr_width:0] count;   // عداد العناصر
    logic [addr_width-1:0] wrptr, rdptr;

    always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        wrptr <= 0;
        rdptr <= 0;
        count <= 0;
        dout  <= '0;

        for (int i = 0; i < dipth; i++) begin
            mem[i] <= '0;
        end
    end
    else begin
        if (wr && !full) begin
            mem[wrptr] <= din;
            wrptr <= wrptr + 1;
            count <= count + 1;
        end

        if (rd && !empty) begin
            dout <= mem[rdptr];
            rdptr <= rdptr + 1;
            count <= count - 1;
        end
    end
end


assign empty = (wrptr == rdptr);
assign full  = ((wrptr - rdptr) == dipth-1);



endmodule

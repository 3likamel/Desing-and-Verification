module serializer #(parameter int Data_WD = 8)
(
    input  wire [Data_WD-1:0] P_DATA,
    input  wire               Data_Valid,
    input  wire               ser_en,
    input  wire               CLK, RST,
    output reg                ser_data,
    output wire               ser_done
);

localparam COUNT_WD = $clog2(Data_WD);

reg [COUNT_WD:0] count;
reg [Data_WD-1:0]  s_data;

assign ser_done = (count == Data_WD);

always_ff @(posedge CLK or negedge RST) begin
    if (!RST)
        s_data <= '0;
    else if (Data_Valid && !ser_en)
        s_data <= P_DATA;
end

always_ff @(posedge CLK or negedge RST) begin
    if (!RST)
        count <= '0;
    else if (!ser_en)
        count <= '0;
    else if (!ser_done)
        count <= count + 1'b1;
end

always_ff @(posedge CLK or negedge RST) begin
    if (!RST)
        ser_data <= 1'b0;
    else if (ser_en && !ser_done)
        ser_data <= s_data[count];
    else
        ser_data <= 1'b0;
end

endmodule

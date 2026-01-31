module ABP_RAM
#( parameter ADDR_WD = 8, parameter DATA_WD = 32 )
(
    input wire                  PCLK,
    input wire                  PRESETn,
    input wire                  PSEL,
    input wire                  PENABLE,
    input wire                  PWRITE,
    input wire  [ADDR_WD-1:0]   PADDR,
    input wire  [DATA_WD-1:0]   PWDATA,
    output reg  [DATA_WD-1:0]   PRDATA,
    output reg                  PREADY,
    output reg                  PSLVERR
);

localparam DEPTH = 1 << ADDR_WD;
reg [DATA_WD-1:0] mem [0:DEPTH-1];
reg ADDR_ERR, ADDRV_ERR, DATA_ERR;


typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ACCESS
} apb_state_t;

apb_state_t current_state, next_state;

// State Transition
always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

// Next State Logic
always_comb begin
    case (current_state)
        IDLE: begin
            if (PSEL)
                next_state = SETUP;
            else
                next_state = IDLE;
        end
        SETUP: begin
            if (PENABLE)
                next_state = ACCESS;
            else
                next_state = SETUP;
        end
        ACCESS: begin
            if (PSEL && PENABLE)
                next_state = ACCESS;
            else
                next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Output Logic
always_comb begin
    if (!PRESETn) begin
        PRDATA  <= '0;
        PREADY  <= 1'b0;
        for (int i = 0; i < (2**ADDR_WD); i++) begin
            mem[i] <= '0;
        end 
    end else begin
        case (current_state)
            IDLE: begin
                PREADY  <= 1'b0;
            end
            SETUP: begin
                PREADY  <= 1'b0;
            end
            ACCESS: begin
                if (!PSLVERR) begin
                    PREADY <= 1'b1;
                    if (PWRITE) begin
                        mem[PADDR] <= PWDATA;
                    end else begin
                        PRDATA <= mem[PADDR];
                    end
                end
            end
        endcase
    end
end

// ERROR DETECTION
assign ADDR_ERR  = ( (next_state == ACCESS ) && (PADDR >= DEPTH) ) ? 1'b1 : 1'b0;
assign ADDRV_ERR = ( (next_state == ACCESS ) && (PADDR >= 0 ) ) ? 1'b0 : 1'b1;
assign DATA_ERR = ( (next_state == ACCESS ) && (PWDATA >= 0 ) ) ? 1'b0 : 1'b1;


assign PSLVERR = (PENABLE && PSEL) ? ( ADDR_ERR | ADDRV_ERR | DATA_ERR) : 1'b0; 


endmodule
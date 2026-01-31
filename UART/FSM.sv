module FSM(
	input wire Data_Valid,
	input wire ser_done,
	input wire PAR_EN,
	input CLK ,RST,
	output reg ser_en,
	output reg [1:0] mux_sel,
	output reg busy
);

typedef enum logic [2:0] {
	idle,
	start,
	serial,
	parity,
	stop
} state_t;

state_t cu_state, nx_state;




always_ff @(posedge CLK,negedge RST)
begin
	if (~RST)
	begin
		cu_state <= idle;
	end
	else if (cu_state == serial && ser_done)
	begin
		if (PAR_EN)
			cu_state <= parity;
		else
			cu_state <= stop;
	end else begin
		cu_state <= nx_state;
	end
end

always_comb
begin
	case (cu_state)
		idle:
		begin
			if (Data_Valid)
			begin
				nx_state = start; 
			end
			else 
			begin
				nx_state = cu_state;
			end
		end
		start:
		begin
			nx_state = serial;
		end
	 	serial:
		begin
			nx_state = cu_state;
		end 
		parity:
		begin
			nx_state = stop;
		end
		stop:
		begin
			if (Data_Valid)
			begin
				nx_state = start;
			end
			else
			begin
				nx_state = idle;
			end
		end
		default:
		begin
			nx_state = idle;
		end
	endcase
end

always_comb
begin
	case (cu_state)
		idle:
		begin
			ser_en  = 1'b0;
			busy 	= 1'b0;
			mux_sel = 2'b01;
		end
		start:
		begin
			ser_en  = 1'b1;
			busy 	= 1'b1;
			mux_sel = 2'b00;
		end
		serial:
		begin
			ser_en  = 1'b1;
			busy 	= 1'b1;
			mux_sel = 2'b10;
		end
		parity:
		begin
			ser_en  = 1'b0;
			busy 	= 1'b1;
			mux_sel = 2'b11;
		end
		stop:
		begin
			ser_en  = 1'b0;
			busy 	= 1'b1;
			mux_sel = 2'b01;
		end
		default:
		begin
			ser_en  = 1'b0;
			busy 	= 1'b0;
			mux_sel = 2'b01;
		end
	endcase

end



/*always_ff @(negedge CLK or negedge RST) begin
	if (RST) begin
		state <= idle;
	end else begin
		case (state)
			idle: begin
				if (Data_Valid) begin
					state <= start;
				end else begin
					state <= idle;
				end
			end
			start: begin
				state <= serial;
			end
			serial: begin
				if (ser_done) begin
					if (PAR_EN) begin
						state <= parity;
					end else begin
						state <= stop;
					end
				end else begin
					state <= serial;
				end
			end
			parity: begin
				state <= stop;
			end
			stop: begin
				if (Data_Valid) begin
					state <= start;
				end else begin
					state <= idle;
				end
			end
			default: begin
				state <= idle;
			end
		endcase
	end
end

// output logic
always_comb begin
	ser_en = 1'b0;
	mux_sel = 2'b00;
	busy = 1'b0;
	
	case (state)
		idle: begin
			ser_en = 1'b0;
			mux_sel = 2'b01; //idle state == tx = stop bit;
			busy = 1'b0;
		end
		start: begin
			ser_en = 1'b0;
			mux_sel = 2'b00; //start bit
			busy = 1'b1;
		end
		serial: begin
			ser_en = 1'b1;
			mux_sel = 2'b10; //data bits
			busy = 1'b1;
		end
		parity: begin
			ser_en = 1'b0;
			mux_sel = 2'b11; //parity bit
			busy = 1'b1;
		end
		stop: begin
			ser_en = 1'b0;
			mux_sel = 2'b01; //stop bit
			busy = 1'b1;
		end
		default: begin
			ser_en = 1'b0;
			mux_sel = 2'b01; //idle state
			busy = 1'b0;
		end
	endcase
end  */
endmodule

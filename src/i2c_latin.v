 `timescale 1ns / 1ps
module I2C_slave_latin#(parameter bits=1, MINION_ADDR=1)(
	//input [bits-2:0]MINION_ADDR,
	input scl,
	input sda_in,
	output sda_out,
	output ctrl,
	input clk,
	input rst,
	input [bits-1:0]data_to_master,
	output [bits-1:0]data_from_master	
	);

localparam idle=0, get_address_and_cmd=1, answer_ack_start=2, write=3; 
localparam read=4, read_ack_start=5,read_ack_got_rising=6, read_stop=7;

reg	[2:0] state_reg;
reg cmd_reg;
integer bits_processed_reg;
reg continue_reg;
reg scl_reg, sda_reg, scl_debounced,sda_debounced, scl_pre_internal,  sda_pre_internal;
reg start_reg, stop_reg, scl_rising_reg, scl_falling_reg;
reg [bits-2:0]addr_reg, data_reg;
reg [bits-1:0]data_from_master_reg, data_to_master_reg;
reg scl_prev_reg, scl_wen_reg, scl_o_reg, sda_prev_reg, sda_wen_reg, sda_o_reg, data_valid_reg, read_req_reg; 
wire scl_internal, sda_internal;
wire sda;

// not debounce
always@(posedge clk)
begin
	scl_pre_internal <= scl;
	sda_pre_internal <= sda;	
end

assign scl_internal=scl_pre_internal?1:0;
assign sda_internal=sda_pre_internal?1:0; 

always@(posedge clk)
begin

    scl_prev_reg   <= scl_internal;
    sda_prev_reg   <= sda_internal;
    scl_rising_reg <= 0;
	
	if(scl_prev_reg == 0 && scl_internal == 1)	begin
		 scl_rising_reg <= 1;
	end
	scl_falling_reg <= 0;	

	if(scl_prev_reg == 1 && scl_internal == 0)	begin
		scl_falling_reg <= 1;
	end

 //Detect I2C START condition
	 start_reg <= 0;
     stop_reg  <= 0;

     if (scl_internal ==1 && scl_prev_reg ==1 && sda_prev_reg ==1 && sda_internal ==0) begin 
        start_reg <= 1;
        stop_reg  <= 0; 
	end

     if (scl_prev_reg ==1 && scl_internal ==1 && sda_prev_reg ==0 && sda_internal ==1) begin
        start_reg <= 0;
        stop_reg  <= 1;
	end

end


// I2C state machine
always@(posedge clk)
begin
	sda_o_reg      <= 0;
    sda_wen_reg    <= 0;

    data_valid_reg <= 0;
    read_req_reg   <= 0;  

	case (state_reg) 

	idle: begin
		if(start_reg==1) begin 
        	state_reg          <= get_address_and_cmd;
            bits_processed_reg <= 0;			
		end		
	end

	get_address_and_cmd: begin
		if(scl_rising_reg ==1) begin
			if(bits_processed_reg < bits-1)begin
            	bits_processed_reg <= bits_processed_reg + 1;
            	addr_reg[bits-2-bits_processed_reg] <= sda_internal;
			end
			else if(bits_processed_reg == bits-1) begin
             	bits_processed_reg <= bits_processed_reg + 1;
            	cmd_reg <= sda_internal;
			end	
		end
  		
		if(bits_processed_reg == bits && scl_falling_reg == 1) begin	
			bits_processed_reg <= 0;
			if(addr_reg == MINION_ADDR) begin
				state_reg <= answer_ack_start;
				if (cmd_reg==1) begin
                	read_req_reg <= 1;
                	data_to_master_reg <= data_to_master;
				end
			end
			else begin
				state_reg <= idle;
			end
		end 
		
	end	
	 
	answer_ack_start: begin
        sda_wen_reg <= 1;
    	sda_o_reg   <= 0;		
		if(scl_falling_reg==1) begin
			if(cmd_reg==0) begin
				state_reg<=write;
			end
			else begin
				state_reg<=read;
			end

		end
	end	

	write: begin
		if(scl_rising_reg==1) begin
			bits_processed_reg <= bits_processed_reg + 1;
			if(bits_processed_reg<bits-1) begin
				data_reg[6-bits_processed_reg] <= sda_internal;	
			end
			else begin
            	data_from_master_reg <= data_reg & sda_internal;
            	data_valid_reg       <= 1;

			end			
		end


		if(scl_falling_reg==1 && bits_processed_reg == bits) begin
            state_reg          <= answer_ack_start;
            bits_processed_reg <= 0;			
		end		
	end	

	read: begin
		sda_wen_reg <= 1;
		if(data_to_master_reg[bits-1-bits_processed_reg]==0) begin
			sda_o_reg <=0;
		end
		else begin
			sda_o_reg <= 1;
		end

		if(scl_falling_reg ==1)begin
			if(bits_processed_reg < bits-1)begin
				bits_processed_reg <= bits_processed_reg + 1;
			end
			else if(bits_processed_reg == bits-1)begin
				state_reg          <= read_ack_start;
              	bits_processed_reg <= 0;
			end
		end			
	end

	read_ack_start: begin
		if(scl_rising_reg==1) begin
			state_reg <= read_ack_got_rising;
			if(sda_internal==1)begin
				continue_reg <=0;
			end
			else begin
             	continue_reg       <= 1;
             	read_req_reg       <= 1; 
             	data_to_master_reg <= data_to_master;				
			end
		end		
	end	

	read_ack_got_rising: begin
		if(scl_falling_reg==1)begin
			if(continue_reg==1)begin
				if(cmd_reg==0) begin
					state_reg <= write;
				end
				else begin
					state_reg <= read;
				end
			end
			else begin
				state_reg <= read_stop;
			end
		end		
	end	

	read_stop: begin
		
	end				
	
	default: begin
		state_reg <= idle;
	end
	endcase

	if(start_reg==1)begin
        state_reg <= get_address_and_cmd;
        bits_processed_reg <= 0;		
	end

	if(stop_reg==1) begin
        state_reg <= idle;
        bits_processed_reg <= 0;		
	end
	
	if(rst==1)begin
		state_reg <= idle;
	end		
end

//assign sda=sda_wen_reg ?sda_o_reg:1'bz;
//assign scl= scl_wen_reg?scl_o_reg:1'bz; 
assign data_from_master = data_from_master_reg;
assign sda=sda_in;
assign sda_out=sda_o_reg;
assign ctrl=sda_wen_reg; //ctrl va conectado a uio_oe;

endmodule
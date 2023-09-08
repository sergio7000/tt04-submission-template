module tt_um_i2c ( 

    input wire  [7:0] ui_in,    // Dedicated inputs - connected to the input switches

    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display

    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path

    output wire [7:0] uio_out,  // IOs: Bidirectional Output path

    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)

    input         ena,      // will go high when the design is enabled

    input         clk,      // clock

    input         rst_n     // reset_n - low to reset

);
    wire rst;
    wire [5:0]data_from_master;
    assign rst=~rst_n; 
    assign uo_out[7:6] =2'b00;
	assign uio_oe[7:2]=6'b111111;
	assign uio_oe[1]=1'b0;

assign uo_out[5:0]=data_from_master; 
assign uio_out[5:0]=data_from_master;

 I2C_slave_latin #(.bits(6), .MINION_ADDR(4'b0010)) i2c1(.scl(uio_in[1]),.sda_in(uio_in[0]),.sda_out(uio_out[0]),.ctrl(uio_oe[0]),.clk(clk),.rst(rst),.data_to_master(uio_in[7:2]),.data_from_master(data_from_master));

  

endmodule

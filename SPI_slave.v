`timescale 1ns / 1ps
module SPI_slave1(clk, SCK, MOSI, pk_dtc_flag, data_8bit, MISO, SSEL, LED, byte_received);
input clk;
input SCK, SSEL, MOSI;
input pk_dtc_flag;
input [7:0]data_8bit;
output wire MISO;
output [7:0]LED;
output reg byte_received;  // high when a byte has been received
//////////////////////////////////////////////////////////////////////////////
// sync SCK to the FPGA clock using a 3-bits shift register
reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges
// same thing for SSEL
wire SSEL_active, SSEL_startmessage, SSEL_endmessage;
reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
assign SSEL_active = ~SSELr[1];  // SSEL is active low
assign SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
assign SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge
// and for MOSI
reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
wire MOSI_data = MOSIr[1];
/////////////////////////////////////////////////////////////////////////////
// we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
reg [2:0] bitcnt;
reg [7:0] byte_data_received;
////////////////////////////////////////Receiver///////////////////////////
always @(posedge clk)
begin
  if(~SSEL_active)
    bitcnt <= 3'b000;
  else
  if(SCK_risingedge)
  begin
    bitcnt <= bitcnt + 3'b001;
    // implement a shift-left register (since we receive the data MSB first)
    byte_data_received <= {byte_data_received[6:0], MOSI_data};
  end
end
always @(posedge clk) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);
// we use the data received to control 8 LEDs
reg [7:0]LED;
always @(posedge clk) if(byte_received) LED <= byte_data_received;

////////////////////////////////Transmitter///////////////////////////////
reg [7:0] byte_data_sent=8'd0;
reg [7:0] cnt = 8'b11001000;//send 200 as the first message for successful connection. 
//always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages
always @(posedge clk)
if(SSEL_active)
begin
//  if(SSEL_startmessage)
//    byte_data_sent <= cnt;  // first byte sent in a message is of successful connection.
//  else
  if(SCK_fallingedge)
  begin
    if(bitcnt==3'b000)//It is being administered by above as both (send/receive) follow the same clocks. 
    begin
    if(pk_dtc_flag)
                begin
                byte_data_sent <= data_8bit;          
                end
                else 
                byte_data_sent <= cnt;//just send 0 after testing of 200. 
    end
    else
      byte_data_sent <= {byte_data_sent[6:0], 1'b0};
  end
end

assign MISO = byte_data_sent[7];  // send MSB first

//The data in "byte_data_sent" will only be updated once it has been completely offloaded. 
// we assume that there is only one slave on the SPI bus
// so we don't bother with a tri-state buffer for MISO
// otherwise we would need to tri-state MISO when SSEL is inactive
endmodule


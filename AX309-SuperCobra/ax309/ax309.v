//------------------------------------------------------------------------------
//
//										Super Cobra - Konami 
//
//------------------------------------------------------------------------------
`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Company: pinballwiz.org
// Engineer: pinballwiz
//
// Create Date:    	13:11:26 12/10/2024
// Design Name:		Super Cobra Arcade
// Module Name:    	AX309
// Project Name: 		Super Cobra
// Target Devices: 	AX309 xilinx spartan 6 (xc6slx16)
// Tool versions: 	ISE 14.7
// Description:		Konami Vertical Arcade (c)1981
//
// Dependencies:
//
// Revision:0.01 - Files Assembled
// Revision 0.02 - Files Edited
// Additional Comments: 
//
// See individual modules for original authors notes.
//
// dip switch settings
//
// dip 1 3 helicopters = 0 4 helicopters = 1
// dip 2 allow game continue once = 0 4 times = 1
// dip 3 upright cabinet = 0 table = 1
// dip 4 1 coin 99 plays = 0
// dip 5 1 coin 99 plays = 1
//-------------------------------------------------------------------------------
module ax309(
	input  wire       CLK_50MHZ,         // 50MHz system clock signal
	input  wire       BTN_nRESET,        // reset push button
	output wire       VGA_HSYNC,         // vga hsync signal
	output wire       VGA_VSYNC,         // vga vsync signal
	output wire [3:0] VGA_RED,           // vga red signal
	output wire [3:0] VGA_GREEN,         // vga green signal
	output wire [3:0] VGA_BLUE,          // vga blue signal
	output wire       AUDIO_L,           // pwm output audio channel
	output wire       AUDIO_R,           // pwm output audio channel
	input  wire 		SW_LEFT,				 // arcade controls are
	input  wire 		SW_RIGHT,			 // gpio pins on j2 header
	input  wire 		SW_UP,				 // controls wired to +3v
	input  wire 		SW_DOWN,				 // with pulldown config in ucf file
	input  wire 		SW_FIRE,				 // so are active high
	input  wire 		SW_BOMB,				 // see ucf file for j2 header info
	output wire [7:0] hex,					 // 7 seg display (disabled)  
	input  wire [2:0] key_in             // ax309 push buttons for coinup etc
    );
//------------------------------------------------------------------------
	wire I_RESET = BTN_nRESET;
	wire CLK_24MHzU;
	wire CLK_24MHz;
	wire RESET = 1'b0;
   wire [3:0] O_VIDEO_R;
   wire [3:0] O_VIDEO_G;
   wire [3:0] O_VIDEO_B;
//------------------------------------------------------------------------
  dcm dcm ( 
    .CLK_IN1(CLK_50MHZ),      // IN 50MHz
    .CLK_OUT1(CLK_24MHzU),    // OUT 24.000MHz
    .CLK_OUT2(CLK_24MHz),     // OUT 24.576MHz
    .RESET(RESET),
    .LOCKED()
	);
//------------------------------------------------------------------------
SCOBRA_TOP u1 (
    .O_VIDEO_R(O_VIDEO_R), 
    .O_VIDEO_G(O_VIDEO_G), 
    .O_VIDEO_B(O_VIDEO_B), 
    .O_HSYNC(O_HSYNC), 
    .O_VSYNC(O_VSYNC), 
    .O_AUDIO_L(O_AUDIO_L), 
    .O_AUDIO_R(O_AUDIO_R),
    .RESET(I_RESET), 
    .clk(CLK_24MHz),
	 .ip_1p({key_in[1],~SW_BOMB,~SW_FIRE,~SW_LEFT,~SW_RIGHT,~SW_UP,~SW_DOWN}),
	 .ip_2p({key_in[2],~SW_BOMB,~SW_FIRE,~SW_LEFT,~SW_RIGHT,~SW_UP,~SW_DOWN}),
    .ip_service(1'b0),
    .ip_dip_switch(5'b10011), // dipsw order = 54321 (see above settings)
    .ip_coin1(key_in[0]),
    .ip_coin2(1'b0)
  );
//--------------------------------------------------------------------
	assign VGA_HSYNC = O_HSYNC;
	assign VGA_VSYNC = O_VSYNC;
	assign VGA_RED   = O_VIDEO_R;
	assign VGA_GREEN = O_VIDEO_G;
	assign VGA_BLUE  = O_VIDEO_B;
	assign AUDIO_L = O_AUDIO_L;
	assign AUDIO_R = O_AUDIO_R;
	assign hex = 8'b11111111;
//-------------------------------------------------------------------------
endmodule

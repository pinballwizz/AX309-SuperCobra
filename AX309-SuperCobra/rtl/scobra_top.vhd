--------------------------------------------------------------------------
-- Arcade: Super Cobra by gaz68 (Sept 2019)
-- https://github.com/gaz68
--------------------------------------------------------------------------
--
-- A simulation model of Scramble hardware
-- Copyright (c) MikeJ - Feb 2007
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email support@fpgaarcade.com
--
-- Revision list
--
-- version 001 initial release
-----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  
  library UNISIM;
  use UNISIM.Vcomponents.all;
-----------------------------------------------------------------------------
entity SCOBRA_TOP is
port (
	O_VIDEO_R        : out std_logic_vector(3 downto 0);
	O_VIDEO_G        : out std_logic_vector(3 downto 0);
	O_VIDEO_B        : out std_logic_vector(3 downto 0);
	O_HSYNC          : out std_logic;
	O_VSYNC          : out std_logic;
   O_HBLANK         : out std_logic;
   O_VBLANK         : out std_logic;

   O_AUDIO_L        : out   std_logic;
   O_AUDIO_R        : out   std_logic;

	ip_dip_switch    : in std_logic_vector(5 downto 1);
	ip_1p            : in std_logic_vector(6 downto 0);
   ip_2p            : in std_logic_vector(6 downto 0);
   ip_service       : in std_logic;
   ip_coin1         : in std_logic;
   ip_coin2         : in std_logic;

	RESET            : in  std_logic;
	clk              : in  std_logic -- 25
);
end;
-----------------------------------------------------------------------------
architecture RTL of SCOBRA_TOP is

  -- scan doubler signals
  signal video_r          : std_logic_vector(3 downto 0);
  signal video_g          : std_logic_vector(3 downto 0);
  signal video_b          : std_logic_vector(3 downto 0);
  signal hsync            : std_logic;
  signal vsync            : std_logic;
  --
  signal video_r_x2       : std_logic_vector(3 downto 0);
  signal video_g_x2       : std_logic_vector(3 downto 0);
  signal video_b_x2       : std_logic_vector(3 downto 0);
  signal hsync_x2         : std_logic;
  signal vsync_x2         : std_logic;

-- ties to audio board
signal audio_addr       : std_logic_vector(15 downto 0);
signal audio_data_out   : std_logic_vector(7 downto 0);
signal audio_data_in    : std_logic_vector(7 downto 0);
signal audio_data_oe_l  : std_logic;
signal audio_rd_l       : std_logic;
signal audio_wr_l       : std_logic;
signal audio_iopc7      : std_logic;
signal audio_reset_l    : std_logic;
signal clk_reset        : std_logic;
signal ena_12           : std_logic;
signal ena_6            : std_logic;
signal ena_6b           : std_logic;
signal ena_1_79         : std_logic;

  -- audio
  signal audio            : std_logic_vector(9 downto 0);
  signal audio_pwm        : std_logic;
  signal I_RESET_L        : std_logic;
--------------------------------------------------------------------------- 
begin

  I_RESET_L <= not RESET;
---------------------------------------------------------------------------
  u_clocks : entity work.SCRAMBLE_CLOCKS
    port map (
      I_CLK      => clk,
      I_RESET_L  => RESET,
      O_ENA_12   => ena_12,   -- 6.25 x 2
      O_ENA_6B   => ena_6b,   -- 6.25 (inverted)
      O_ENA_6    => ena_6,    -- 6.25
      O_ENA_1_79 => ena_1_79, -- 1.786
      O_RESET    => clk_reset
      );
---------------------------------------------------------------------------
u_scobra : entity work.SCOBRA
port map (
	--
	O_VIDEO_R             => video_r,
	O_VIDEO_G             => video_g,
	O_VIDEO_B             => video_b,
	O_HSYNC               => hsync,
	O_VSYNC               => vsync,
   O_HBLANK              => O_HBLANK,
   O_VBLANK              => O_VBLANK,
	--
	-- to audio board
	--
	O_ADDR                => audio_addr,
	O_DATA                => audio_data_out,
	I_DATA                => audio_data_in,
	I_DATA_OE_L           => audio_data_oe_l,
	O_RD_L                => audio_rd_l,
	O_WR_L                => audio_wr_l,
	O_IOPC7               => audio_iopc7,
	O_RESET_WD_L          => audio_reset_l,
	--
	ENA                   => ena_6,
	ENAB                  => ena_6b,
	ENA_12                => ena_12,
	--
	RESET                 => clk_reset,
	CLK                   => clk
);
-----------------------------------------------------------------------------
  u_scan_doubler : entity work.SCRAMBLE_DBLSCAN
    port map (
      I_R          => video_r,
      I_G          => video_g,
      I_B          => video_b,
      I_HSYNC      => hsync,
      I_VSYNC      => vsync,
      --
      O_R          => video_r_x2,
      O_G          => video_g_x2,
      O_B          => video_b_x2,
      O_HSYNC      => hsync_x2,
      O_VSYNC      => vsync_x2,
      --
      ENA_X2       => ena_12,
      ENA          => ena_6,
      CLK          => clk
      );

  p_video_ouput : process
  begin
    wait until rising_edge(clk);
      O_VIDEO_R(3 downto 0) <= video_r_x2;
      O_VIDEO_G(3 downto 0) <= video_g_x2;
      O_VIDEO_B(3 downto 0) <= video_b_x2;
      O_HSYNC   <= hsync_x2;
      O_VSYNC   <= vsync_x2;
  end process;
------------------------------------------------------------------------------
--
--
-- audio subsystem
--
u_audio : entity work.SCOBRA_AUDIO
port map (
	--
	I_ADDR             => audio_addr,
	I_DATA             => audio_data_out,
	O_DATA             => audio_data_in,
	O_DATA_OE_L        => audio_data_oe_l,
	--
	I_RD_L             => audio_rd_l,
	I_WR_L             => audio_wr_l,
	I_IOPC7            => audio_iopc7,
	--
	O_AUDIO            => audio,
	--
	I_1P_CTRL          => ip_1p, -- start, shoot1, shoot2, left,right,up,down
	I_2P_CTRL          => ip_2p, -- start, shoot1, shoot2, left,right,up,down
	I_SERVICE          => ip_service,
	I_COIN1            => ip_coin1,
	I_COIN2            => ip_coin2,
	O_COIN_COUNTER     => open,
	--
	I_DIP              => ip_dip_switch,
	--
	I_RESET_L          => audio_reset_l,
	ENA                => ena_6,
	ENA_1_79           => ena_1_79,
	CLK                => clk
);
----------------------------------------------------------------------------------
  --
  -- Audio DAC
  --
  u_dac : entity work.dac
    generic map(
      msbi_g => 9
    )
    port  map(
      clk_i   => clk,
      res_n_i => RESET,
      dac_i   => audio,
      dac_o   => audio_pwm
    );
  O_AUDIO_L <= audio_pwm;
  O_AUDIO_R <= audio_pwm;
----------------------------------------------------------------------------------
end RTL;
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
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  
  library UNISIM;
  use UNISIM.Vcomponents.all;

entity SCOBRA is
  port (
    --
    O_VIDEO_R             : out   std_logic_vector(3 downto 0);
    O_VIDEO_G             : out   std_logic_vector(3 downto 0);
    O_VIDEO_B             : out   std_logic_vector(3 downto 0);
    O_HSYNC               : out   std_logic;
    O_VSYNC               : out   std_logic;
    O_HBLANK              : out   std_logic;
    O_VBLANK              : out   std_logic;
    --
    -- to audio board
    --
    O_ADDR                : out   std_logic_vector(15 downto 0);
    O_DATA                : out   std_logic_vector( 7 downto 0);
    I_DATA                : in    std_logic_vector( 7 downto 0);
    I_DATA_OE_L           : in    std_logic;
    O_RD_L                : out   std_logic;
    O_WR_L                : out   std_logic;
    O_IOPC7               : out   std_logic;
    O_RESET_WD_L          : out   std_logic;
    --
    ENA                   : in    std_logic;
    ENAB                  : in    std_logic;
    ENA_12                : in    std_logic;
    --
    RESET                 : in    std_logic; -- active high
    CLK                   : in    std_logic
    );
end;

architecture RTL of SCOBRA is

    type  array_4x8   is array (0 to 3) of std_logic_vector(7 downto 0);
    -- timing
    signal hcnt             : std_logic_vector(8 downto 0) := "010000000"; -- 80
    signal vcnt             : std_logic_vector(8 downto 0) := "011111000"; -- 0F8

    signal reset_wd_l       : std_logic;

    -- timing decode
    signal do_hsync         : boolean;
    signal set_vblank       : boolean;
    signal vsync            : std_logic;
    signal hsync            : std_logic;
    signal vblank           : std_logic;
    signal hblank           : std_logic;
    --
    -- cpu
    signal cpu_ena          : std_logic;
    signal cpu_mreq_l       : std_logic;
    signal cpu_rd_l         : std_logic;
    signal cpu_wr_l         : std_logic;
    signal cpu_rfsh_l       : std_logic;
    signal cpu_wait_l       : std_logic;
    signal cpu_int_l        : std_logic;
    signal cpu_nmi_l        : std_logic;
    signal cpu_busrq_l      : std_logic;
    signal cpu_addr         : std_logic_vector(15 downto 0);
    signal cpu_data_out     : std_logic_vector(7 downto 0);
    signal cpu_data_in      : std_logic_vector(7 downto 0);

    signal page_4to7_l      : std_logic;

    signal wren             : std_logic;

    signal objen_l          : std_logic;
    signal waen_l           : std_logic;

    signal objramrd_l       : std_logic;
    signal vramrd_l         : std_logic;

    signal select_l         : std_logic;
    signal objramwr_l       : std_logic;
    signal vramwr_l         : std_logic;

    -- control reg
    signal control_reg      : std_logic_vector(7 downto 0);
    signal intst_l          : std_logic;
    signal iopc7            : std_logic;
    signal pout1            : std_logic;
    signal starson          : std_logic;
    signal hcma             : std_logic;
    signal vcma             : std_logic;

    signal pgm_rom_dout     : array_4x8;
    signal rom_dout         : std_logic_vector(7 downto 0);
    signal ram_dout         : std_logic_vector(7 downto 0);
    signal ram_ena          : std_logic;

    signal vram_data        : std_logic_vector(7 downto 0);

begin

  O_HBLANK <= hblank;
  O_VBLANK <= vblank;

  --
  -- video timing
  --
  p_hvcnt : process
    variable hcarry,vcarry : boolean;
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      hcarry := (hcnt = "111111111");
      if hcarry then
        hcnt <= "010000000"; -- 080
      else
        hcnt <= hcnt +"1";
      end if;
      -- hcnt 8 on circuit is 256H_L
      vcarry := (vcnt = "111111111");
      if do_hsync then
        if vcarry then
          vcnt <= "011111000"; -- 0F8
        else
          vcnt <= vcnt +"1";
        end if;
      end if;
    end if;
  end process;

  p_sync_comb : process(hcnt, vcnt)
  begin
    vsync <= not vcnt(8);
    do_hsync <= (hcnt = "010101111"); -- 0AF
    set_vblank <= (vcnt = "111101111"); -- 1EF
  end process;

  p_sync : process
  begin
    wait until rising_edge(CLK);
    -- Timing hardware is coded differently to the real hw
    -- to avoid the use of multiple clocks. Result is identical.
    if (ENA = '1') then
      if (hcnt = "010001001") then -- 089 (081 according to schematics?)
        hblank <= '1';
      elsif (hcnt = "011111111") then -- 0FF (0F9 according to schematics?)
        hblank <= '0';
      end if;

      if do_hsync then
        hsync <= '1';
      elsif (hcnt = "011001111") then -- 0CF
        hsync <= '0';
      end if;

      if do_hsync then
        if set_vblank then -- 1EF
          vblank <= '1';
        elsif (vcnt = "100001111") then -- 10F
          vblank <= '0';
        end if;
      end if;
    end if;
  end process;

  p_video_timing_reg : process
  begin
    wait until rising_edge(CLK);
    -- match output delay in video module
    if (ENA = '1') then
      O_HSYNC     <= HSYNC;
      O_VSYNC     <= VSYNC;
    end if;
  end process;

  p_cpu_ena : process(hcnt, ENA)
  begin
    -- cpu clocked on rising edge of 1h, late
    cpu_ena <= ENA and hcnt(0); -- 1h
  end process;
  --
  -- video
  --
  u_video : entity work.SCOBRA_VIDEO
    port map (
      --
      I_HCNT          => hcnt,
      I_VCNT          => vcnt,
      I_VBLANK        => vblank,
      I_VSYNC         => vsync,

      I_VCMA          => vcma,
      I_HCMA          => hcma,
      --
      I_CPU_ADDR      => cpu_addr,
      I_CPU_DATA      => cpu_data_out,
      O_VRAM_DATA     => vram_data,
      -- note, looks like the real hardware cannot read from object ram
      --
      I_VRAMWR_L      => vramwr_l,
      I_VRAMRD_L      => vramrd_l,
      I_OBJRAMWR_L    => objramwr_l,
      I_OBJRAMRD_L    => objramrd_l,
      I_OBJEN_L       => objen_l,
      --
      I_STARSON       => starson,
      I_POUT1         => pout1,
      --
      O_VIDEO_R       => O_VIDEO_R,
      O_VIDEO_G       => O_VIDEO_G,
      O_VIDEO_B       => O_VIDEO_B,
      --
      ENA             => ENA,
      ENAB            => ENAB,
      ENA_12          => ENA_12,
      CLK             => CLK
      );

  -- other cpu signals
  reset_wd_l <= not RESET; -- FIX

  p_cpu_wait : process(vblank, hblank, waen_l)
  begin
    -- this is done a bit differently, the original had a late
    -- clock to the cpu, and as mreq came out a litle early it could assert
    -- wait and then gate off the write strobe to vram/objram in time.
    --
    -- we are a nice synchronous system therefore we need to do this combinatorially.
    -- timing is still ok.
    --
    if (vblank = '1') then
      cpu_wait_l <='1';
    else
      cpu_wait_l <= '1';
      if (hblank = '0') and (waen_l = '0') then
        cpu_wait_l <= '0';
      end if;
    end if;
  end process;
  wren <= cpu_wait_l;

  p_cpu_int : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (intst_l = '0') then
        cpu_nmi_l <= '1';
      else
        if do_hsync and set_vblank then
          cpu_nmi_l <= '0';
        end if;
      end if;
    end if;
  end process;

  u_cpu : entity work.T80sed
          port map (
              RESET_n => reset_wd_l,
              CLK_n   => clk,
              CLKEN   => cpu_ena,
              WAIT_n  => cpu_wait_l,
              INT_n   => cpu_int_l,
              NMI_n   => cpu_nmi_l,
              BUSRQ_n => cpu_busrq_l,
              M1_n    => open,
              MREQ_n  => cpu_mreq_l,
              IORQ_n  => open,
              RD_n    => cpu_rd_l,
              WR_n    => cpu_wr_l,
              RFSH_n  => cpu_rfsh_l,
              HALT_n  => open,
              BUSAK_n => open,
              A       => cpu_addr,
              DI      => cpu_data_in,
              DO      => cpu_data_out
              );
  --
  -- primary addr decode
  --
  p_mem_decode : process(cpu_rfsh_l, cpu_rd_l, cpu_wr_l, cpu_mreq_l, cpu_addr)
  begin
  -- Super Cobra map
  --0000-7fff ROM
  --8000-87ff RAM
  --8800-8bff Video RAM
  --9000-90ff Object RAM
  --  9000-903f  screen attributes
  --  9040-905f  sprites
  --  9060-907f  bullets
  --  9080-90ff  unused?

  --read:
  --B000      Watchdog Reset
  --9800      IN0
  --9801      IN1
  --9802      IN2 (bits 5 and 7 used for protection check in Scramble)

  --write:
  --A800-A807 control reg
  --A000      To AY-3-8910 port A (commands for the audio CPU)
  --A001      bit 3 = interrupt trigger on audio CPU  bit 4 = AMPM (?)
  --A002      protection check control?

    cpu_int_l   <= '1';
    cpu_busrq_l <= '1';

    page_4to7_l <= '1';
    if (cpu_mreq_l = '0') and (cpu_rfsh_l = '1') then
      if (cpu_addr(15 downto 14) = "10") then page_4to7_l <= '0'; end if;
    end if;

  end process;

  p_mem_decode2 : process(cpu_addr, page_4to7_l, cpu_rfsh_l, cpu_rd_l, cpu_wr_l, wren)
  begin
    waen_l <= '1';
    objen_l <= '1';
    if (page_4to7_l = '0') and (cpu_rfsh_l = '1') then
      if (cpu_addr(13 downto 11) = "001") then waen_l <= '0'; end if;
      if (cpu_addr(13 downto 11) = "010") then objen_l <= '0'; end if;
    end if;

    -- read decode
    vramrd_l <= '1';
    objramrd_l <= '1';

	 if (page_4to7_l = '0') and (cpu_rd_l = '0') then
	   if (cpu_addr(13 downto 11) = "001") then vramrd_l <= '0'; end if;
	   if (cpu_addr(13 downto 11) = "010") then objramrd_l <= '0'; end if;
	 end if;

    -- write decode
    vramwr_l <= '1';
    objramwr_l <= '1';
    select_l <= '1';

    if (page_4to7_l = '0') and (cpu_wr_l = '0') and (wren = '1') then
      if (cpu_addr(13 downto 11) = "001") then vramwr_l <= '0'; end if;
      if (cpu_addr(13 downto 11) = "010") then objramwr_l <= '0'; end if;
      if (cpu_addr(13 downto 11) = "101") then select_l <= '0'; end if; -- control reg
    end if;
  end process;

  p_control_reg : process
    variable addr : std_logic_vector(2 downto 0);
    variable dec : std_logic_vector(7 downto 0);
  begin
     wait until rising_edge(CLK);
     if (ENA = '1') then
    -- Super Cobra
    --a801      interrupt enable
    --a802      coin counter
    --a803      ? (POUT1)
    --a804      stars on
    --a805      ? (POUT2)
    --a806      screen vertical flip
    --a807      screen horizontal flip
      addr := cpu_addr(2 downto 0);

      dec := "00000000";
      if (select_l = '0') then
        case addr(2 downto 0) is
          when "000" => dec := "00000001";
          when "001" => dec := "00000010";
          when "010" => dec := "00000100";
          when "011" => dec := "00001000";
          when "100" => dec := "00010000";
          when "101" => dec := "00100000";
          when "110" => dec := "01000000";
          when "111" => dec := "10000000";
          when others => null;
        end case;
      end if;

      if (reset_wd_l = '0') then
        control_reg <= (others => '0');
      else
        for i in 0 to 7 loop
          if (dec(i) = '1') then
            control_reg(i) <= cpu_data_out(0);
          end if;
        end loop;
      end if;
    end if;
  end process;

  p_control_reg_assign : process(control_reg)
  begin
    intst_l <= control_reg(1);
    iopc7   <= control_reg(2);
    pout1   <= control_reg(3);
    starson <= control_reg(4);
    hcma    <= control_reg(6);
    vcma    <= control_reg(7);
  end process;
-----------------------------------------------------------------------------
--  roms / rams
-----------------------------------------------------------------------------
  pgm_rom : entity work.ROM_PGM
    port map (CLK => CLK, ADDR => cpu_addr(14 downto 0), DATA => rom_dout);
-----------------------------------------------------------------------------
  u_cpu_ram : entity work.SCRAMBLE_RAM
    port map (
      I_ADDR => cpu_addr(10 downto 0),
      I_DATA => cpu_data_out,
      O_DATA => ram_dout,
      I_RW_L => cpu_wr_l,
      I_CS   => ram_ena,
      ENA    => ENA,
      CLK    => CLK
      );
-----------------------------------------------------------------------------
--	pgm_rom : work.dpram generic map (15,8)
--	port map
--	(
--		clock_a   => clk,
--		wren_a    => dn_wr and (not dn_addr(15)),
--		address_a => dn_addr(14 downto 0),
--		data_a    => dn_data,

--		clock_b   => CLK,
--		address_b => cpu_addr(14 downto 0),
--		q_b       => rom_dout
--	);
-----------------------------------------------------------------------------
--	u_cpu_ram : work.dpram generic map (11,8)
--	port map
--	(
--		clock_a   => clk,
--		enable_a  => ena,
--		wren_a    => ram_ena and (not cpu_wr_l),

--		address_a => cpu_addr(10 downto 0),
--		data_a    => cpu_data_out,

--		clock_b   => clk,
--		address_b => cpu_addr(10 downto 0),
--		q_b       => ram_dout
--	);
-----------------------------------------------------------------------------
  p_ram_ctrl : process(cpu_addr, page_4to7_l)
  begin
    ram_ena <= '0';
    if (page_4to7_l = '0') and (cpu_addr(13 downto 11) = "000") then
      ram_ena <= '1';
    end if;
  end process;

  p_cpu_data_in_mux : process(cpu_addr, cpu_rd_l, cpu_mreq_l, cpu_rfsh_l, ram_dout, rom_dout, vramrd_l, vram_data, I_DATA_OE_L, I_DATA )
    variable ram_addr : std_logic_vector(1 downto 0);
  begin

    cpu_data_in <= (others => '0');
    if    (vramrd_l = '0') then
      cpu_data_in <= vram_data;
    --
    elsif (I_DATA_OE_L = '0') then
      cpu_data_in <= I_DATA;
    --
    elsif (cpu_mreq_l = '0') and (cpu_rfsh_l = '1') then
      if (cpu_addr(15) = '0') and (cpu_rd_l = '0') and (cpu_mreq_l = '0') and (cpu_rfsh_l = '1') then
        cpu_data_in <= rom_dout;
      --
      elsif (cpu_addr(15 downto 14) = "10") then
        if (cpu_addr(13 downto 11) = "000") and (cpu_rd_l = '0') then
          cpu_data_in <= ram_dout;
        else
          cpu_data_in <= x"FF";
        end if;
      end if;
    else
      cpu_data_in <= x"FF";
    end if;

  end process;

  -- to audio
  O_ADDR                <= cpu_addr;
  O_DATA                <= cpu_data_out;
  O_RD_L                <= cpu_rd_l;
  O_WR_L                <= cpu_wr_l;
  O_IOPC7               <= iopc7;
  O_RESET_WD_L          <= reset_wd_l;

end RTL;

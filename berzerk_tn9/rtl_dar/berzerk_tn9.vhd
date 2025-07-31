---------------------------------------------------------------------------------
--                          Berzerk - Tang Nano 9k
--                     Original Code by DarFPGA (see below)
--
--                        Modified for Tang Nano 9k 
--                            by pinballwiz.org 
--                               29/07/2025
---------------------------------------------------------------------------------
-- DE10_lite Top level berzerk by Dar (darfpga@aol.fr) (21/06/2018)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
-- Use berzerk_de10_lite.sdc to compile (Timequest constraints)
-- /!\
-- Don't forget to set device configuration mode with memory initialization 
--  (Assignments/Device/Pin options/Configuration mode)
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input @gpio pins 35/34 (beware voltage translation/protection) 
--  Audio pwm output   @gpio pins 1/3 (beware voltage translation/protection) 
--
-- Uses 1 pll for 10MHz generation from 50MHz
--
-- Board key :
--   0 : reset game
--
-- Board switch :
--	  1 : tv 15Khz mode / VGA 640x480 mode
--
-- Keyboard players inputs :
--
--   F3 : Add coin
--   F2 : Start 2 players
--   F1 : Start 1 player
--   SPACE       : fire
--   RIGHT arrow : move right
--   LEFT  arrow : move left
--   UP    arrow : move up 
--   DOWN  arrow : move down
--
-- Sound effects : OK
-- Speech synthesis : todo 
--
-- Other details : see berzerk.vhd
-- For USB inputs and SGT5000 audio output see my other project: xevious_de10_lite
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
---------------------------------------------------------------------------------
entity berzerk_tn9 is
port(
    clock_27  : in std_logic;

    key       : in std_logic_vector(1 downto 0);
    led       : out std_logic_vector(5 downto 0);

 	vga_r     : out std_logic;
	vga_g     : out std_logic;
	vga_b     : out std_logic;

	vga_hs    : out std_logic;
	vga_vs    : out std_logic;
		
	ps2_clk   : in std_logic;
	ps2_dat   : inout std_logic;

 	audio_l   : out std_logic;
	audio_r   : out std_logic
);
end berzerk_tn9;
----------------------------------------------------------------------------------
architecture struct of berzerk_tn9 is

 signal clock_10  : std_logic;
 signal reset     : std_logic;

 signal r         : std_logic;
 signal g         : std_logic;
 signal b         : std_logic;

 signal hi        : std_logic;
 signal csync     : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal sw        : std_logic_vector(9 downto 0);

 signal video_r   : std_logic_vector(3 downto 0);
 signal video_g   : std_logic_vector(3 downto 0);
 signal video_b   : std_logic_vector(3 downto 0);
 
 signal audio     : std_logic_vector(15 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 alias reset_n    : std_logic is key(0);

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal joyHBCPPFRLDU : std_logic_vector(9 downto 0);

 constant CLOCK_FREQ  : integer := 27E6;
 signal counter_clk   : std_logic_vector(25 downto 0);
 signal clock_4hz     : std_logic;
   
 signal dbg_cpu_di    : std_logic_vector( 7 downto 0);
 signal dbg_cpu_addr  : std_logic_vector(15 downto 0);
 signal dbg_cpu_addr_latch : std_logic_vector(15 downto 0);
---------------------------------------------------------------------------------------
component Gowin_rPLL
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;
---------------------------------------------------------------------------------------
begin

reset <= not reset_n;
---------------------------------------------------------------------------------------
-- Clock 10MHz for Berzerk core

clocks: Gowin_rPLL
    port map (
        clkout => clock_10,
        clkin => clock_27
    );
---------------------------------------------------------------------------------------
-- berzerk

berzerk : entity work.berzerk
port map(
 clock_10   => clock_10,
 reset      => reset,

 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_hi     => hi, 
 video_csync  => csync,
 video_hs     => hsync,
 video_vs     => vsync,
 audio_out    => audio,
  
 start2   => joyHBCPPFRLDU(6),
 start1   => joyHBCPPFRLDU(5),
 coin1    => joyHBCPPFRLDU(7),
 cocktail => '0',
 
 right1 => joyHBCPPFRLDU(3),
 left1  => joyHBCPPFRLDU(2),
 down1  => joyHBCPPFRLDU(1),
 up1    => joyHBCPPFRLDU(0),
 fire1  => joyHBCPPFRLDU(4),
 
 right2 => joyHBCPPFRLDU(3),
 left2  => joyHBCPPFRLDU(2),
 down2  => joyHBCPPFRLDU(1),
 up2    => joyHBCPPFRLDU(0),
 fire2  => joyHBCPPFRLDU(4),

 sw           => sw,

 dbg_cpu_di   => dbg_cpu_di,
 dbg_cpu_addr => dbg_cpu_addr,
 dbg_cpu_addr_latch => dbg_cpu_addr_latch
);
---------------------------------------------------------------------------------------------
-- debug

process(reset, clock_27)
begin
  if reset = '1' then
    clock_4hz <= '0';
    counter_clk <= (others => '0');
  else
    if rising_edge(clock_27) then
      if counter_clk = CLOCK_FREQ/8 then
        counter_clk <= (others => '0');
        clock_4hz <= not clock_4hz;
        led(5 downto 0) <= not dbg_cpu_addr(9 downto 4);
      else
        counter_clk <= counter_clk + 1;
      end if;
    end if;
  end if;
end process;
----------------------------------------------------------------------------------------------
-- vga output

vga_r <= r;
vga_g <= g;
vga_b <= b;

vga_hs <= hsync;
vga_vs <= vsync;
-----------------------------------------------------------------------------------------------
-- get scancode from keyboard

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_10, -- use same clock as main core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);
-----------------------------------------------------------------------------------------------
-- translate scancode to joystick

joystick : entity work.kbd_joystick
port map (
  clk          => clock_10, -- use same clock as main core
  kbdint       => kbd_intr,
  kbdscancode  => std_logic_vector(kbd_scancode), 
  joyHBCPPFRLDU => joyHBCPPFRLDU
 -- keys_HUA     => open --keys_HUA
);
------------------------------------------------------------------------------------------------
-- pwm sound output

process(clock_10)  -- use same clock as sound_board
begin
  if rising_edge(clock_10) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio(15 downto 4)));
  end if;
end process;

audio_l <= pwm_accumulator(12);
audio_r <= pwm_accumulator(12); 
------------------------------------------------------------------------------------------------
end struct;
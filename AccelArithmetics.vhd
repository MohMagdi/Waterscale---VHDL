----------------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Author:  Albert Fazakas
--          Copyright 2014 Digilent, Inc.
----------------------------------------------------------------------------
-- 
-- Create Date:    14:45:49 03/05/2014 
-- Design Name: 
-- Module Name:    AccelArithmetics - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--       This module transforms the incoming acceleration data from the ADXL_Control module into a format
--    that is displayed on the VGA screen:
--       - The incoming ACCEL_X_IN, ACCEL_Y_IN and ACCEL_Z_IN data is on 2g scale (-2g to +2g) represented on
--       12 bits two's complement
--       - The ACCEL_Y_IN data is inverted, according to the accelerometer layout position on the Nexys4 board
--
--       - Both ACCEL_X_IN and ACCEL_Y_IN are scaled and limited to ACC_X_Y_MIN - ACC_X_Y_MAX (by default 0-511),
--       meaning: -1g: ACC_X_Y_MIN, 0g: (ACC_X_Y_MAX - ACC_X_Y_MIN)/2, 1g: ACC_X_Y_MAX. In this case will be
--       -1g: 0, 0g: 255 and 1g: 511, corresponding to the accelerometer data display on the VGA screen of 512 * 512
--       pixels.
--
--       - The acceleration magnitude is calculated according to the formula SQRT (ACC_X^2 + ACC_Y^2 + ACC_Z^2). For square 
--       root calculation, a Logicore Square Root component is used. Due to the scaling purposes on the screen, the result 
--       of the square root calculation is also divided by four.
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use ieee.math_real.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_signed.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AccelArithmetics is
generic 
(
   SYSCLK_FREQUENCY_HZ : integer := 100000000;
   ACC_X_Y_MAX         : STD_LOGIC_VECTOR (9 downto 0) := "01" & X"FF"; -- 511 pixels, corresponding to +1g
   ACC_X_Y_MIN         : STD_LOGIC_VECTOR (9 downto 0) := (others => '0') -- corresponding to -1g
);
port
(
 SYSCLK     : in STD_LOGIC; -- System Clock
 RESET      : in STD_LOGIC;
 
 -- Accelerometer data input signals
 ACCEL_X_IN    : in STD_LOGIC_VECTOR (11 downto 0);
 ACCEL_Y_IN    : in STD_LOGIC_VECTOR (11 downto 0);
 ACCEL_Z_IN    : in STD_LOGIC_VECTOR (11 downto 0);
 Data_Ready    : in STD_LOGIC;

 -- Accelerometer data output signals to be sent to the VGA display
 ACCEL_X_OUT    : out STD_LOGIC_VECTOR (8 downto 0);
 ACCEL_Y_OUT    : out STD_LOGIC_VECTOR (8 downto 0);
 ACCEL_MAG_OUT  : out STD_LOGIC_VECTOR (11 downto 0)
);
end AccelArithmetics;

architecture Behavioral of AccelArithmetics is
-- convert ACCEL_X and ACCEL_Y data to unsigned and divide by 4 
-- (scaled to 0-1023, with -2g=0, 0g=511, 2g=1023)
-- Then limit to -1g = 0, 0g = 255, 1g = 511

-- Use a Square Root Logicore component to calculate the magnitude
COMPONENT Square_Root
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;
  
COMPONENT div_gen_0
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

COMPONENT cordic_0 
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;

constant scale : std_logic_vector (12 downto 0) := "1000000000000"; --4096

-- Invert Y axis data in order to display it on the screen correctly
signal ACCEL_Y_IN_INV : STD_LOGIC_VECTOR (11 downto 0);

signal ACCEL_X_SUM : std_logic_vector (12 downto 0) := (others => '0'); -- one more bit to keep the sign extension
signal ACCEL_Y_SUM : std_logic_vector (12 downto 0) := (others => '0');
signal ACCEL_Z_SUM : std_logic_vector (12 downto 0) := (others => '0');

signal ACCEL_X_SUM_SHIFTED : std_logic_vector (9 downto 0) := (others => '0'); -- Divide the sum by four
signal ACCEL_Y_SUM_SHIFTED : std_logic_vector (9 downto 0) := (others => '0');
signal ACCEL_Z_SUM_SHIFTED : std_logic_vector (9 downto 0) := (others => '0');


-- Calculate magnitude

-- Pipe Data_Ready
signal Data_Ready_0, Data_Ready_1,Data_Ready_2,Data_Ready_3,Data_Ready_4 : std_logic := '0';

signal ACCEL_X_SQUARE : std_logic_vector (23 downto 0) := (others => '0');
signal ACCEL_Y_SQUARE : std_logic_vector (23 downto 0) := (others => '0');
signal ACCEL_Z_SQUARE : std_logic_vector (23 downto 0) := (others => '0');

signal ACCEL_MAG_SQUARE : std_logic_vector (31 downto 0) := (others => '0');
signal ACCEL_MAG_SQRT: std_logic_vector (13 downto 0) := (others => '0');
signal m_axis_dout_tdata: std_logic_vector (15 downto 0);

signal Angle_Y : std_logic_vector (8 downto 0);
signal div_out : STD_LOGIC_VECTOR(23 DOWNTO 0);
signal scale_out : STD_LOGIC_VECTOR(23 DOWNTO 0);
signal scaled : STD_LOGIC_VECTOR(8 downto 0);
signal atan_out : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal atan_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal extend_Y : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal temp2,data_echo : std_logic;

begin

-- Invert Accel_Y data to display on the screen the box movement on the Y axis according to the board movement
ACCEL_Y_IN_INV <= (NOT ACCEL_Y_IN) + X"001";

extend_Y <= "0000" & ACCEL_Y_IN;
-- Calculate squares of the incoming acceleration values
Calculate_Square: process (SYSCLK, Data_Ready, ACCEL_X_IN, ACCEL_Y_IN, ACCEL_Z_IN)
begin
   if rising_edge(SYSCLK) then
      if Data_Ready = '1' then 
         ACCEL_X_SQUARE <= ACCEL_X_IN * ACCEL_X_IN;
         ACCEL_Y_SQUARE <= ACCEL_Y_IN * ACCEL_Y_IN;
         ACCEL_Z_SQUARE <= ACCEL_Z_IN * ACCEL_Z_IN;
      end if;
   end if;
end process Calculate_Square;

-- Calculate the sum of the squares
sum_of_squares_X2_Z2: process (SYSCLK, Data_Ready_0, ACCEL_X_SQUARE, ACCEL_Y_SQUARE, ACCEL_Z_SQUARE)
begin
   if SYSCLK'EVENT and SYSCLK = '1' then
      if Data_Ready_0 = '1' then 
         ACCEL_MAG_SQUARE <= "000000" & (("00" & ACCEL_X_SQUARE) + ("00" & ACCEL_Z_SQUARE));
      end if;
   end if;
end process;

-- Calculate the square root to determine magnitude
sqrt_of_sum_of_squares: Square_Root
  PORT MAP (
    aclk => SYSCLK,
    s_axis_cartesian_tvalid => Data_Ready_1,
    s_axis_cartesian_tdata => (ACCEL_MAG_SQUARE),
    m_axis_dout_tvalid => open,--Data_Ready_2,
    m_axis_dout_tdata => m_axis_dout_tdata
  );

Y_divided_sqrt : div_gen_0 Port map
(
    aclk => SYSCLK,
    s_axis_divisor_tvalid => Data_Ready_2,
    s_axis_divisor_tdata => m_axis_dout_tdata,
    s_axis_dividend_tvalid => Data_Ready_2,--data_echo,
    s_axis_dividend_tdata => extend_Y,
    m_axis_dout_tvalid => open,--Data_Ready_3,
    m_axis_dout_tdata => div_out
);

scaledown :  div_gen_0 Port map
(
    aclk => SYSCLK,
    s_axis_divisor_tvalid => Data_Ready_3,
    s_axis_divisor_tdata => "000"&scale,
    s_axis_dividend_tvalid => Data_Ready_3,
    s_axis_dividend_tdata => div_out(23 downto 8),
    m_axis_dout_tvalid => open,--Data_Ready_4,
    m_axis_dout_tdata => scale_out
);

atan_in <= scale_out(13 downto 0) & "000000000000000000";
atan: cordic_0 Port map
(
    aclk  => SYSCLK,
    s_axis_cartesian_tvalid => Data_Ready_4,
    s_axis_cartesian_tdata => atan_in,
    m_axis_dout_tvalid => open,--temp2,
    m_axis_dout_tdata => atan_out
);

Angle_Y <= atan_out(8 downto 0);

-- ACCEL_X_CLIP and ACCEL_Y_CLIP values (0-511) can be represented on 9 bits
ACCEL_X_OUT <= ACCEL_X_SUM_SHIFTED(8 downto 0);
ACCEL_Y_OUT <= Angle_Y;

-- Pipe Data_Ready
Pipe_Data_Ready : process (SYSCLK, RESET, Data_Ready, Data_Ready_0)
begin
   if SYSCLK'EVENT and SYSCLK = '1' then
      if RESET = '1' then
         Data_Ready_0 <= '0';
         Data_Ready_1 <= '0';
         Data_Ready_2 <= '0';
         Data_Ready_3 <= '0';
         Data_Ready_4 <= '0';
      else
         Data_Ready_0 <= Data_Ready;
         Data_Ready_1 <= Data_Ready_0;
         Data_Ready_2 <= Data_Ready_1;
         Data_Ready_3 <= Data_Ready_2;
         Data_Ready_4 <= Data_Ready_3;
      end if;
   end if;
end process Pipe_Data_Ready;


-- Also divide the square root by 4
ACCEL_MAG_OUT <= ACCEL_MAG_SQRT(13 downto 2);

end Behavioral;


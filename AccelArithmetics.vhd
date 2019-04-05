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
   SYSCLK_FREQUENCY_HZ : integer := 100000000--9  "01" &...
);
port
(
 SYSCLK     : in STD_LOGIC; -- System Clock
 RESET      : in STD_LOGIC;
 
 -- Accelerometer data input signals~~~~~~~~~~~~~~~~~~~until here we handle 12 bits
 ACCEL_Y_IN    : in STD_LOGIC_VECTOR (11 downto 0);
 Data_Ready    : in STD_LOGIC;

 -- Accelerometer data output signals thermometer encoded ~~~~~~~~befre this data was sent to the vga
 ACCEL_Y_OUT    : out STD_LOGIC_VECTOR (11 downto 0)
);
end AccelArithmetics;

architecture Behavioral of AccelArithmetics is
-- convert ACCEL_X and ACCEL_Y data to unsigned and divide by 4 
-- (scaled to 0-1023, with -2g=0, 0g=511, 2g=1023)
-- Then limit to -1g = 0, 0g = 255, 1g = 511

constant LOWER_ACC_BOUNDARY : std_logic_vector (9 downto 0) := "00" & X"FF"; -- 255
constant UPPER_ACC_BOUNDARY : std_logic_vector (9 downto 0) := "10" & X"FF"; -- 767

-- Invert Y axis data in order to display it on the screen correctly
signal ACCEL_Y_IN_INV : STD_LOGIC_VECTOR (11 downto 0);

signal ACCEL_Y_SUM : std_logic_vector (12 downto 0) := (others => '0');

signal ACCEL_Y_SUM_SHIFTED : std_logic_vector (9 downto 0) := (others => '0');

-- Pipe Data_Ready
signal Data_Ready_0, Data_Ready_1 : std_logic := '0';

begin

ACCEL_Y_OUT <= ACCEL_Y_IN;


-- Pipe Data_Ready
Pipe_Data_Ready : process (SYSCLK, RESET, Data_Ready, Data_Ready_0)
begin
   if SYSCLK'EVENT and SYSCLK = '1' then
      if RESET = '1' then
         Data_Ready_0 <= '0';
         Data_Ready_1 <= '0';
      else
         Data_Ready_0 <= Data_Ready;
         Data_Ready_1 <= Data_Ready_0;
      end if;
   end if;
end process Pipe_Data_Ready;

end Behavioral;


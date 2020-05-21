----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:25:31 04/10/2012 
-- Design Name: 
-- Module Name:    EdgeDetect - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--   edge detector for both rising and falling edge
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity EdgeDetect is
	port(
		clk			: in std_logic;
		reset		: in std_logic;
		level		: in std_logic;
		tick_rise	: out std_logic;
		tick_fall	: out std_logic
	);
end EdgeDetect;

architecture Behavioral of EdgeDetect is

signal delay_reg: std_ulogic;

begin
   -- delay register
	process(clk,reset)
	begin
		if (clk'event and clk='1') then
			if (reset='1') then
				delay_reg <= '0';
			else
				delay_reg <= level;
			end if;
		end if;
   end process;
   -- decoding logic
   tick_rise <= (not delay_reg) and level;
   tick_fall <= delay_reg and (not level);

end Behavioral;

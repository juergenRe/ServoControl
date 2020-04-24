----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:44:55 04/09/2012 
-- Design Name: 
-- Module Name:    Debounce - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
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

-- Listing 5.6
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity Debounce is
   generic (
		N			: integer := 19		--counting size: 2^N * 20ns = 10ms tick
   );
   port(
		clk			: in std_logic;
		reset		: in std_logic;
		sw			: in std_logic;			--bouncing input
		db			: out std_logic			--debounced output
   );
end Debounce;

architecture arch of Debounce is
   signal q_reg, q_next			: unsigned(N-1 downto 0);
   signal m_tick				: std_logic;
   type eg_state_type is (zero,wait1_1,wait1_2,wait1_3,
                          one,wait0_1,wait0_2,wait0_3);
   signal state_reg, state_next	: eg_state_type := zero;
begin
   --===================================
   -- counter to generate 10 ms tick
   -- (2^N * TCLK)
   --===================================
   process(clk,reset)
   begin
	  if (reset = '1') then
		 q_reg <= (others =>'0');
	  end if;
      if (clk'event and clk='1') then
         q_reg <= q_next;
      end if;
   end process;
   -- next-state logic
   q_next <= q_reg + 1;
   --output tick
   m_tick <= '1' when q_reg=0 else
             '0';
   --===================================
   -- debouncing FSM
   --===================================
   -- state register
   process(clk,reset)
   begin
      if (reset='1') then
         state_reg <= zero;
      elsif (clk'event and clk='1') then
         state_reg <= state_next;
      end if;
   end process;
   -- next-state/output logic
   process(state_reg,sw,m_tick)
   begin
      state_next <= state_reg; --default: back to same state
      db <= '0';   -- default 0
      case state_reg is
         when zero =>
            if sw='1' then
               state_next <= wait1_1;
            end if;
         when wait1_1 =>
            if sw='0' then
               state_next <= zero;
            else
               if m_tick='1' then
                  state_next <= wait1_2;
               end if;
            end if;
         when wait1_2 =>
            if sw='0' then
               state_next <= zero;
            else
               if m_tick='1' then
                  state_next <= wait1_3;
               end if;
            end if;
         when wait1_3 =>
            if sw='0' then
               state_next <= zero;
            else
               if m_tick='1' then
                  state_next <= one;
               end if;
            end if;
         when one =>
            db <='1';
            if sw='0' then
               state_next <= wait0_1;
            end if;
         when wait0_1 =>
            db <='1';
            if sw='1' then
               state_next <= one;
            else
               if m_tick='1' then
                  state_next <= wait0_2;
               end if;
            end if;
         when wait0_2 =>
            db <='1';
            if sw='1' then
               state_next <= one;
            else
               if m_tick='1' then
                  state_next <= wait0_3;
               end if;
            end if;
         when wait0_3 =>
            db <='1';
            if sw='1' then
               state_next <= one;
            else
               if m_tick='1' then
                  state_next <= zero;
               end if;
            end if;
      end case;
   end process;
end arch;


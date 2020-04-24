----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/22/2020 09:14:57 AM
-- Design Name: 
-- Module Name: ServoCtl_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ServoCtl_tb is
end ServoCtl_tb;

architecture Behavioral of ServoCtl_tb is
   -- Clock period definitions
constant clk_period:    time := 10 ns;

   --internal signals
signal clk:             std_logic := '0';
signal reset:           std_logic := '0';

-- inputs to ServoCtrl block
constant NP:            integer := 3;
constant NC:            integer := 2;
constant DIV:           integer := 5;

signal outVal:          std_logic_vector(NP-1 downto 0) := (others => '0');
signal chan:            std_logic_vector(3 downto 0) := (others => '0');
signal trg:             std_logic := '0';
signal rdy:             std_logic;
signal pwm:             std_logic_vector(NC-1 downto 0);
  
component ServoCtrl is
    generic (
        NP:         integer;      -- bits of precision
        NC:         integer;        -- number of channels
        DIV:        integer      -- prescaler count
    );
    port (
        clk:        in std_logic;
        outVal:     in std_logic_vector(NP-1 downto 0);        -- output value
        chan:       in std_logic_vector(3 downto 0);           -- channel to be set
        trg:        in std_logic;                              -- triggers setting of new value
        rdy:        out std_logic;                             -- ready to take new command
        pwm:        out std_logic_vector(NC-1 downto 0)        -- output pwm signal
        );
end component;

begin
    uut: ServoCtrl
    generic map (
        NP => NP,
        NC => NC,
        DIV => DIV
    )
    port map (
        clk => clk,
        outVal => outVal,
        chan => chan,
        trg => trg,
        rdy => rdy,
        pwm => pwm
    );

	-- Clock process definitions
	clk_process :process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;
	
 
   -- Stimulus process
    stim_proc: process
    begin
        wait for 40 ns;
        reset <= '1';
        wait for 100ns;
        reset <= '0';
		wait for 800 ns;
		
		-- set channel 0
		chan <= "0000";
		outVal <= std_logic_vector(to_signed(2, NP));
		wait until falling_edge(clk);
		trg <= '1';
		wait until (falling_edge(clk) and rdy = '0');
		trg <= '0';
		wait until (falling_edge(clk) and rdy = '1');
		
		-- set channel 1
		chan <= "0001";
		outVal <= std_logic_vector(to_signed(7, NP));
		wait until falling_edge(clk);
		trg <= '1';
		wait until (falling_edge(clk) and rdy = '0');
		trg <= '0';
		wait until (falling_edge(clk) and rdy = '1');
		wait for 1us;

		wait for 2us;
    end process;

end Behavioral;

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

entity ServoControl_tb is
end ServoControl_tb;

architecture Behavioral of ServoControl_tb is
   -- Clock period definitions
constant clk_period:    time := 10 ns;

   --internal signals
signal clk:             std_logic := '0';
signal reset:           std_logic := '0';

-- inputs to ServoCtrl block
constant NP:            integer := 3;
constant NC:            integer := 2;
constant NDIV:          integer := 4;
constant DIVCNT:        integer := 5;
constant DIVCNT2:       integer := 9;
constant N_AXI:         integer := 32;

signal outVal:          std_logic_vector(NP-1 downto 0) := (others => '0');
signal chan:            std_logic_vector(3 downto 0) := (others => '0');
signal cfg:             std_logic_vector(N_AXI-1 downto 0) := (others => '0');
signal inVal:           std_logic_vector(N_AXI-1 downto 0);
signal wrTrg:           std_logic := '0';
signal rdTick:          std_logic;
signal pwm:             std_logic_vector(NC-1 downto 0);

signal div:             std_logic_vector(NDIV -1 downto 0);
signal cmdWr:           std_logic := '0';
signal outEna:          std_logic := '0';
  
component ServoCtrlWrapper is
	generic (
		-- Users to add parameters here
        C_U_NP                  : integer := 16;      -- max bits of precision
        C_U_NC                  : integer := 4;        -- max number of channels
        C_U_NDIV                : integer := 16;        -- max size for prescale counter
		C_S_AXI_DATA_WIDTH	    : integer := 32
	);
	port (
	    clk         : in std_logic;
	    reset       : in std_logic;
		-- channel number where to write value
        U_CHAN      : in std_logic_vector(3 downto 0);
        --  pwm value
        U_VAL       : in std_logic_vector(C_U_NP-1 downto 0);
        -- configuration and control word:
        -- U_CFG(U_C_NDIV-1 downto 0) --> actual prescale value; will be changed with every prescale tick
        -- U_CFG(31) = trg            --> latch new values with falling edge
        -- U_CFG(30) = ONOFF          --> global on/off of all pwm signals
        U_CFG       : in std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line
		U_WR_TICK   : in std_logic;
		U_RD_DATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		U_RD_TICK   : out std_logic;
		pwm_out     : out std_logic_vector(C_U_NC-1 downto 0)
	);
end component;

begin
    uut: ServoCtrlWrapper
    generic map (
        C_U_NP => NP,
        C_U_NC => NC,
        C_U_NDIV => NDIV,
        C_S_AXI_DATA_WIDTH => N_AXI
    )
    port map (
        clk => clk,
        reset => reset,
        U_CHAN  => chan,
        U_VAL  => outVal,
        U_CFG => cfg,
        U_WR_TICK => wrTrg,
        U_RD_DATA => inVal,
        U_RD_TICK => rdTick,
        pwm_out => pwm
    );

	-- Clock process definitions
	clk_process :process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;
	
 
    cfg(NDIV-1 downto 0) <= div;
    cfg(31) <= outEna;

   -- Stimulus process
    stim_proc: process
        procedure TrgReqWaitAck is
        variable actStatus: std_logic;
        begin
            actStatus := inVal(31);
    		wrTrg <= '1';
            while actStatus = '1' loop
                wait until rising_edge(rdTick);
                actStatus := inVal(31);
            end loop;        
    		wrTrg <= '0';
            while actStatus = '0' loop
                wait until rising_edge(rdTick);
                actStatus := inVal(31);
            end loop;        
        end TrgReqWaitAck;
    begin
        -- check behaviour when no reset is given
        div <= std_logic_vector(to_unsigned(DIVCNT, NDIV));
        wait for 1000 ns;
        reset <= '1';
        wait for 100ns;
        reset <= '0';
		wait for 800 ns;
		
		-- set channel 0
		chan <= "0000";
		outVal <= std_logic_vector(to_signed(2, NP));
		outEna <= '0';
		wait until falling_edge(clk);
		cmdWr <= '1';
		TrgReqWaitAck;
		wait until falling_edge(clk);
		cmdWr <= '0';
		
		-- set channel 1
		chan <= "0001";
		outVal <= std_logic_vector(to_signed(7, NP));
		outEna <= '1';
		wait until falling_edge(clk);
		cmdWr <= '1';
		TrgReqWaitAck;
		wait until falling_edge(clk);
		cmdWr <= '0';

		wait for 1500ns;
        div <= std_logic_vector(to_unsigned(DIVCNT2, NDIV));
		outEna <= '1';
		wait until falling_edge(clk);
		cmdWr <= '1';
		TrgReqWaitAck;
		wait until falling_edge(clk);
		cmdWr <= '0';

		wait for 2us;
		outEna <= '0';
		wait until falling_edge(clk);
		cmdWr <= '1';
		TrgReqWaitAck;
		wait until falling_edge(clk);
		cmdWr <= '0';
		
		wait for 10us;
    end process;

end Behavioral;

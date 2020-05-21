----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/30/2020 02:41:33 PM
-- Design Name: 
-- Module Name: ServoCtrlWrapper - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ServoCtrlWrapper is
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
        -- U_CFG(31) = ONOFF          --> global on/off of all pwm signals
        U_CFG       : in std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		-- output from AXI-module: '1' for one cycle when data is written.
		-- validates U_CHAN, U_VAL and U_CFG
		U_WR_TICK   : in std_logic;
		U_RD_DATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		-- input to AXI-module: writes actual U_RD_DATA value in register 3 as status to be read
		U_RD_TICK   : out std_logic;
		pwm_out     : out std_logic_vector(C_U_NC-1 downto 0)
	);
end ServoCtrlWrapper;

architecture Behavioral of ServoCtrlWrapper is
    constant CFG_ONOFF:     integer := C_S_AXI_DATA_WIDTH -1;
    constant CFG_STATUS:    integer := C_S_AXI_DATA_WIDTH -1;
    constant STATUS_RDY:    std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0) := x"80000000";
    constant STATUS_RUN:    std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0) := x"00000000";
    
    signal pwm_channel:     std_logic_vector(3 downto 0);
    signal pwm_value:       std_logic_vector(C_U_NP-1 downto 0);
    signal pwm_cfg:         std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
    signal pwm_reset:       std_logic;
    signal pwm_trg:         std_logic;
    signal pwm_rdy:         std_logic;
    signal pwmDivideReg:    std_logic_vector(C_U_NDIV-1 downto 0);
    signal pwmDivideNxt:    std_logic_vector(C_U_NDIV-1 downto 0);
    signal pwm_o:           std_logic_vector(C_U_NC-1 downto 0);
    
    signal cfg_tick:        std_logic;
    signal rdy_tick:        std_logic;
    signal run_tick:        std_logic;
    signal status:          std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);

    type t_stSetTrg is (stPwrOn, stIdle, stWaitCfgStart, stWaitCfg);
    signal stSetTrgReg:     t_stSetTrg;    
    signal stSetTrgNxt:     t_stSetTrg;
    
    type t_stSetDiv is (stPwrOn, stIdle);
    signal stSetDivReg:     t_stSetDiv;    
    signal stSetDivNxt:     t_stSetDiv;
    
    component ServoCtrl is
        generic (
            NP:         integer;      -- bits of precision
            NC:         integer;        -- number of channels
            NDIV:       integer      -- prescaler count
        );
        port (
            clk:        in std_logic;
            reset:      in std_logic;
            outVal:     in std_logic_vector(NP-1 downto 0);        -- output value
            chan:       in std_logic_vector(3 downto 0);           -- channel to be set
            trg:        in std_logic;                              -- triggers setting of new value
            rdy:        out std_logic;                             -- ready to take new command
            div:        in std_logic_vector(NDIV-1 downto 0);      -- prescaler value 
            pwm:        out std_logic_vector(NC-1 downto 0)        -- output pwm signal
        );
    end component;
    
    component EdgeDetect is
	port(
		clk			: in std_logic;
		reset		: in std_logic;
		level		: in std_logic;
		tick_rise	: out std_logic;
		tick_fall	: out std_logic
	);
end component;


begin

	edge_btn_k: EdgeDetect
    port map (
        clk         => clk,
        reset       => reset,
        level       => status(CFG_STATUS),
        tick_rise   => rdy_tick,
        tick_fall   => run_tick
    );
	
    servo_ctl: ServoCtrl
    generic map (
        NP      => C_U_NP,
        NC      => C_U_NC,
        NDIV    => C_U_NDIV
    )
    port map (
        clk     => clk,
        reset   => reset, 
        outVal  => pwm_value,
        chan    => pwm_channel,
        trg     => pwm_trg,
        rdy     => pwm_rdy,
        div     => pwmDivideReg,
        pwm     => pwm_o
    );

    pwm_out <= pwm_o when pwm_cfg(CFG_ONOFF) = '1' else (others => '0');
    pwm_channel <= U_CHAN; 
    pwm_value <= U_VAL;
    pwm_cfg <= U_CFG;
    cfg_tick <= U_WR_TICK;
    
    -- transfer actual status to AXI read register
    status <= STATUS_RDY when stSetTrgReg = stIdle else STATUS_RUN;
    U_RD_DATA <= status;
    U_RD_TICK <= rdy_tick or run_tick;

    -- set the divider with each cfg tick from the processor
    set_div_reg: process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                stSetDivReg <= stPwrOn;
                pwmDivideReg <= (others => '1');
            else
                pwmDivideReg <= pwmDivideNxt;
                stSetDivReg <= stSetDivNxt;
            end if;
        end if;
    end process set_div_reg;
    
    set_div_nxt: process(stSetDivReg, pwmDivideReg, cfg_tick, pwm_cfg)
    begin
        stSetDivNxt <= stSetDivReg;
        pwmDivideNxt <= pwmDivideReg;
        case stSetDivReg is
            when stPwrOn =>
                stSetDivNxt <= stIdle;
                pwmDivideNxt <= (others => '1');
            when stIdle =>
                if cfg_tick = '1' then
                    pwmDivideNxt <= pwm_cfg(C_U_NDIV-1 downto 0);
                end if;
        end case;
    end process set_div_nxt;
    
    -- handle trigger of the pwm control
    set_trg_reg: process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset ='1' then
                stSetTrgReg <= stPwrOn;
            else
                stSetTrgReg <= stSetTrgNxt;
            end if;
        end if;
    end process set_trg_reg;
    
    set_trg_nxt: process(stSetTrgReg, pwm_rdy, cfg_tick)
    begin
        stSetTrgNxt <= stSetTrgReg;
        pwm_trg <= '0';
        case stSetTrgReg is
            when stPwrOn =>
                stSetTrgNxt <= stIdle;
            when stIdle =>
                if pwm_rdy = '1' and cfg_tick = '1' then
                    stSetTrgNxt <= stWaitCfgStart;
                    pwm_trg <= '1';
                end if;
            when stWaitCfgStart =>
                if pwm_rdy = '0' then
                    stSetTrgNxt <= stWaitCfg;
                end if;
            when stWaitCfg =>
                if pwm_rdy = '1' then
                    stSetTrgNxt <= stIdle;
                end if;
        end case;
    end process set_trg_nxt;
    
end Behavioral;

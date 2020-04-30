----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/22/2020 04:50:45 PM
-- Design Name: 
-- Module Name: ServoTest - Behavioral
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

entity ServoTest is
    Port ( 
        clk         : in std_logic;
        led         : out std_logic_vector(3 downto 0);
        btn         : in std_logic_vector(3 downto 0);
        sw          : in std_logic_vector(1 downto 0);
        pwm         : out std_logic_vector(3 downto 0)
    );
end ServoTest;

architecture Behavioral of ServoTest is

-- inputs to ServoCtrl block
--constant NP:            integer := 3;
--constant NC:            integer := 2;
--constant DIV:           integer := 5;
constant NP:            integer := 12;
constant NC:            integer := 2;
constant NDIV:          integer := 9; 
constant DIVCNT:        integer := 250;         -- actual division count
constant NMin:          integer := 112;         -- minimum value to be set for minimum pulse length of ca. 0.5ms
constant NBtn:          integer := 4;

signal outVal:          std_logic_vector(NP-1 downto 0);
signal outValBase:      std_logic_vector(NP-1 downto 0);
--signal outValNxt:       std_logic_vector(NP-1 downto 0);        -- output value
signal chan:            std_logic_vector(3 downto 0);
signal chanNxt:         std_logic_vector(3 downto 0);
signal trg:             std_logic;
signal rdy:             std_logic;
signal pwmi:            std_logic_vector(NC-1 downto 0);
signal div:             std_logic_vector(NDIV-1 downto 0);
  
signal btn_edge:        std_logic_vector(NBtn-1 downto 0);
signal btn_dbc:         std_logic_vector(NBtn-1 downto 0);
signal swTick:          std_logic_vector(1 downto 0);
signal lunused:         std_logic_vector(NBtn-1 downto 0);
signal btnSet:          std_logic_vector(NBtn-1 downto 0);
signal btnSetNxt:       std_logic_vector(NBtn-1 downto 0);
signal btnTick:         std_logic;

type t_stTran is (
    stPwrOn,
    stIdle,
    stWaitTrg,
    stSetTrg,
    stWaitActive,
    stWaitDone
);
signal stTranReg:       t_stTran;
signal stTranNxt:       t_stTran;

------------------------------------------------------------------------------------
-- debug attributes
attribute mark_debug : string;
attribute mark_debug of btn_edge: signal is "true";
attribute mark_debug of swTick: signal is "true";
attribute mark_debug of btnTick: signal is "true";
attribute mark_debug of stTranReg: signal is "true";
attribute mark_debug of outVal: signal is "true";
attribute mark_debug of chan: signal is "true";
attribute mark_debug of trg: signal is "true";
attribute mark_debug of rdy: signal is "true";
attribute mark_debug of pwmi: signal is "true";

------------------------------------------------------------------------------------
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

component Debounce is
   generic (
		N			: integer := 19		--counting size: 2^N * 20ns = 10ms tick
   );
   port(
		clk			: in std_logic;
		reset		: in std_logic;
		sw			: in std_logic;			--bouncing input
		db			: out std_logic			--debounced output
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

function sumTick(inTickVect: std_logic_vector) return std_logic is
variable tv: std_logic;
begin
    tv := '0';
    for i in inTickVect'range loop
        if inTickVect(i) = '1' then
            tv := '1';
        end if;
    end loop;
    return tv;
end sumTick;

------------------------------------------------------------------------------------

begin
    servo_ctl: ServoCtrl
    generic map (
        NP => NP,
        NC => NC,
        NDIV => NDIV
    )
    port map (
        clk => clk,
        reset => '0',
        outVal => outVal,
        chan => chan,
        trg => trg,
        rdy => rdy,
        div => div,
        pwm => pwmi
    );

div <= std_logic_vector(to_unsigned(DIVCNT, NDIV));
pwm(NC-1 downto 0) <= pwmi;
pwm(3 downto NC) <= (others => '0');

-- generate debounced button signals
dbce_gen_btn: for k in 0 to NBtn-1 generate
    dbnc_btn_k: Debounce
        generic map (
            N       => 20
        )
        port map(
            clk			=> clk,
            reset		=> '0',
            sw			=> btn(k),
            db			=> btn_dbc(k)
        );
end generate dbce_gen_btn;
   
-- generate edge detectors
edge_gen_btn: for k in 0 to NBtn-1 generate
    edge_btn_k: EdgeDetect
    port map (
        clk         => clk,
        reset       => '0',
        level       => btn_dbc(k),
        tick_rise   => btn_edge(k),
        tick_fall   => open
    );
end generate edge_gen_btn;

edge_gen_sw: for k in 0 to 1 generate
    edge_sw_k: EdgeDetect
        port map (
            clk         => clk,
            reset       => '0',
            level       => sw(k),
            tick_rise   => swTick(k),
            tick_fall   => open
        );
end generate edge_gen_sw;
----------------------------------------------------
-- SW(0) = 0: set channel
-- SW(0) = 1: set pwm
-- SW(1) toggle: transfer
-- each button will set/reset the corresponding bit and show it on led
lunused <= (others => '0');
outValBase <= std_logic_vector(to_unsigned(NMin, NP));
outVal <= "00"&btnSet&outValBase(NP-NBtn-3 downto 0);
led <= chan when sw(0) = '0' else btnSet;
btnTick <= sumTick(btn_edge);

set_data_reg: process(clk)
begin
    if rising_edge(clk) and btnTick = '1' then
        chan <= chanNxt;
        btnSet <= btnSetNxt;
    end if;
end process set_data_reg;

set_data_nxt: process(chan, outVal, sw, btn_edge)
begin
    chanNxt <= chan;
    btnSetNxt <= btnSet;
    if sw(0) = '0' then
        chanNxt <= chan xor btn_edge;
    else
        btnSetNxt <= btnSet xor btn_edge;
    end if;
end process set_data_nxt;

--------------------------------------------------------------
-- state machine to transfer data to pwm component    
proc_trans_reg: process(clk)
begin
    if rising_edge(clk) then
        stTranReg <= stTranNxt;
    end if;
end process proc_trans_reg;

proc_trans_nxt: process(stTranReg, swTick, rdy)
begin
    stTranNxt <= stTranReg;
    trg <= '0';
    case stTranReg is
        when stPwrOn => 
            if rdy = '1' then
                stTranNxt <= stIdle;
            end if;
        when stIdle => 
            if swTick(1) = '1' then
                stTranNxt <= stWaitTrg;
            end if;
        when stWaitTrg => 
            if rdy = '1' then
                stTranNxt <= stSetTrg;
            end if;
        when stSetTrg => 
            trg <= '1';
            stTranNxt <= stWaitActive;
        when stWaitActive => 
            if rdy = '0' then
                stTranNxt <= stWaitDone;
            end if;
        when stWaitDone => 
            if rdy = '1' then
                stTranNxt <= stIdle;
            end if;
    end case;
end process proc_trans_nxt;

end Behavioral;

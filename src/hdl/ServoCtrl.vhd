----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/22/2020 09:01:08 AM
-- Design Name: 
-- Module Name: ServoCtrl - Behavioral
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
use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ServoCtrl is
    generic (
        NP:         integer := 10;      -- bits of precision
        NC:         integer := 2;        -- number of channels
        DIV:        integer := 50      -- prescaler count
    );
    port (
        clk:        in std_logic;
        outVal:     in std_logic_vector(NP-1 downto 0);        -- output value
        chan:       in std_logic_vector(3 downto 0);           -- channel to be set
        trg:        in std_logic;                              -- triggers setting of new value
        rdy:        out std_logic;                             -- ready to take new command
        pwm:        out std_logic_vector(NC-1 downto 0)        -- output pwm signal
    );
end ServoCtrl;

architecture Behavioral of ServoCtrl is

signal preCnt:      integer range 0 to DIV;
signal tickPreCnt:  std_logic;

type tSetVal is (stPwrOn, stIdle, stSetValPre, stSetVal);
signal stSetValReg:     tSetVal;
signal stSetValNxt:     tSetVal;

-- pwm counter definitions
type tPWMregister is array(integer range 0 to NC-1) of std_logic_vector(NP-1 downto 0);
signal pwmCounterReg:   std_logic_vector(NP-1 downto 0);       --  actual counter value
signal pwmCounterNxt:   std_logic_vector(NP-1 downto 0);       
signal direction:       std_logic;
signal dirNxt:          std_logic;

signal cmpRegister:     tPWMregister;                          --  compare values
signal cmpVal:          std_logic_vector(NC-1 downto 0);

signal cntZero:         std_logic_vector(NP-1 downto 0);
signal cntMax:          std_logic_vector(NP-1 downto 0);
signal cntZeroTick:     std_logic;

begin

    -- prescaler to reduce input clock
clk_div: process (clk)
begin
    if rising_edge(clk) then
        if preCnt >= DIV-1 then
            preCnt <= 0;
         else
            preCnt <= preCnt + 1;
         end if;
     end if;
end process clk_div;
tickPreCnt <= '1' when (preCnt = 0) else '0';

-------------------------------------------------------------------
-- pwm counter: realized as up/down counter between min and max value
cntZero <= (others => '0');
cntMax <= (others => '1');

pwm_cnt_reg: process (clk, tickPreCnt)
begin
    if rising_edge(clk) and tickPreCnt = '1' then
        pwmCounterReg <= pwmCounterNxt;
        direction <= dirNxt;
    end if;
end process pwm_cnt_reg;

pwm_cnt_nxt: process (pwmCounterReg, direction, stSetValReg)
begin
    pwmCounterNxt <= pwmCounterReg;
    dirNxt <= direction;
    if stSetValReg = stPwrOn then
        pwmCounterNxt <= (others => '0');
        dirNxt <= '1';
    else
        if direction = '1' then
            if pwmCounterReg = cntMax then
                dirNxt <= '0';
                pwmCounterNxt <= pwmCounterReg - 1;
            else
                pwmCounterNxt <= pwmCounterReg + 1;
            end if;
        else
            if pwmCounterReg = cntZero then
                dirNxt <= '1';
                pwmCounterNxt <= pwmCounterReg + 1;
            else
                pwmCounterNxt <= pwmCounterReg - 1;
            end if;
        end if;
        
    end if;
end process pwm_cnt_nxt;

-------------------------------------------------------------------
-- output compare logic
out_cmp: for k in 0 to NC-1 generate
    cmpVal(k) <= '0' when pwmCounterReg >= cmpRegister(k) else '1';
end generate out_cmp;
--cmpVal(NC -1 downto 1) <= (others => '0');
pwm <= cmpVal;

-------------------------------------------------------------------
-- state machine to set the pwm values
proc_setVal_reg: process(clk)
variable ichan: integer range 0 to NC - 1;
begin
    ichan := to_integer(unsigned(chan));
    if rising_edge(clk) then
        stSetValReg <= stSetValNxt;
        if stSetValReg = stPwrOn then
            cmpRegister <= (others => (others => '0'));
        elsif cntZeroTick = '1' then
            cmpRegister(ichan) <= outVal;
        end if;
    end if;
end process proc_setVal_reg;

proc_setVal_nxt: process(stSetValReg, trg, pwmCounterReg, chan)
begin
    stSetValNxt <= stSetValReg;
    cntZeroTick <= '0';
    case stSetValReg is
        when stPwrOn =>
            stSetValNxt <= stIdle;
        when stIdle =>
            if trg = '1' then
                stSetValNxt <= stSetValPre;
            end if;
        when stSetValPre =>
            if (pwmCounterReg /= cntZero) then
                stSetValNxt <= stSetVal;
            end if;
        when stSetVal =>
            if pwmCounterReg = cntZero then
                cntZeroTick <= '1';
                stSetValNxt <= stIdle;
            end if;
    end case;
end process proc_setVal_nxt;

rdy <= '1' when (stSetValReg = stIdle) else '0';
end Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ServoControl_v1_0 is
	generic (
		-- Users to add parameters here
        C_U_NP          : integer := 16;      -- max bits of precision
        C_U_NC          : integer := 4;        -- max number of channels
        C_U_NDIV        : integer := 16;        -- max size for prescale counter
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		-- Users to add ports here
        pwmi            : out std_logic_vector(C_U_NC-1 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end ServoControl_v1_0;

architecture arch_imp of ServoControl_v1_0 is
    constant CFG_TRG:       integer := C_S00_AXI_DATA_WIDTH -1;
    constant CFG_ONOFF:     integer := C_S00_AXI_DATA_WIDTH -2;
    signal pwm_channel:     std_logic_vector(C_U_NC-1 downto 0);
    signal pwm_value:       std_logic_vector(C_U_NP-1 downto 0);
    signal pwm_cfg:         std_logic_vector(C_S00_AXI_DATA_WIDTH -1 downto 0);
    signal pwm_reset:       std_logic;
    signal pwm_trg:         std_logic;
    signal pwm_rdy:         std_logic;
    signal pwm_divide:      std_logic_vector(C_U_NDIV-1 downto 0);
    signal pwm_out:         std_logic_vector(C_U_NC-1 downto 0);
    
    signal cfg_tick:        std_logic;

    type t_stSetTrg is (stPwrOn, stIdle, stWaitCfgStart, stWaitCfg);
    signal stSetTrgReg:     t_stSetTrg;    
    signal stSetTrgNxt:     t_stSetTrg;
    
	-- component declaration
        -- configuration and control word:
        -- U_CFG(U_C_NDIV-1 downto 0) --> actual prescale value; will be changed with every prescale tick
        -- U_CFG(31) = trg            --> latch new values with falling edge
        -- U_CFG(30) = ONOFF          --> global on/off of all pwm signals
	component ServoControl_v1_0_S00_AXI is
		generic (
        C_U_NP_AXI          : integer := 16;      -- max bits of precision
        C_U_NC_AXI          : integer := 4;        -- max number of channels
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
		);
		port (
        U_CHAN          : out std_logic_vector(C_U_NC_AXI-1 downto 0);
        U_VAL           : out std_logic_vector(C_U_NP_AXI-1 downto 0);
        U_CFG           : out std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
        
		S_AXI_ACLK	    : in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	    : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	    : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
		);
	end component ServoControl_v1_0_S00_AXI;

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

-- Instantiation of Axi Bus Interface S00_AXI
ServoControl_v1_0_S00_AXI_inst : ServoControl_v1_0_S00_AXI
	generic map (
	    C_U_NP_AXI          => C_U_NP,
	    C_U_NC_AXI          => C_U_NC,
		C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
	)
	port map (
	    U_CHAN          => pwm_channel,
	    U_VAL           => pwm_value,
	    U_CFG           => pwm_cfg,
	    ------------------------------- 
		S_AXI_ACLK	    => s00_axi_aclk,
		S_AXI_ARESETN	=> s00_axi_aresetn,
		S_AXI_AWADDR	=> s00_axi_awaddr,
		S_AXI_AWPROT	=> s00_axi_awprot,
		S_AXI_AWVALID	=> s00_axi_awvalid,
		S_AXI_AWREADY	=> s00_axi_awready,
		S_AXI_WDATA	    => s00_axi_wdata,
		S_AXI_WSTRB	    => s00_axi_wstrb,
		S_AXI_WVALID	=> s00_axi_wvalid,
		S_AXI_WREADY	=> s00_axi_wready,
		S_AXI_BRESP	    => s00_axi_bresp,
		S_AXI_BVALID	=> s00_axi_bvalid,
		S_AXI_BREADY	=> s00_axi_bready,
		S_AXI_ARADDR	=> s00_axi_araddr,
		S_AXI_ARPROT	=> s00_axi_arprot,
		S_AXI_ARVALID	=> s00_axi_arvalid,
		S_AXI_ARREADY	=> s00_axi_arready,
		S_AXI_RDATA	    => s00_axi_rdata,
		S_AXI_RRESP	    => s00_axi_rresp,
		S_AXI_RVALID	=> s00_axi_rvalid,
		S_AXI_RREADY	=> s00_axi_rready
	);

	-- Add user logic here
	
	edge_btn_k: EdgeDetect
    port map (
        clk         => s00_axi_aclk,
        reset       => pwm_reset,
        level       => pwm_cfg(CFG_TRG),
        tick_rise   => cfg_tick,
        tick_fall   => open
    );
	
    servo_ctl: ServoCtrl
    generic map (
        NP      => C_U_NP,
        NC      => C_U_NC,
        NDIV    => C_U_NDIV
    )
    port map (
        clk     => s00_axi_aclk,
        reset   => pwm_reset, 
        outVal  => pwm_value,
        chan    => pwm_channel,
        trg     => pwm_trg,
        rdy     => pwm_rdy,
        div     => pwm_divide,
        pwm     => pwm_out
    );

    pwm_reset <= not s00_axi_aresetn;
    pwmi <= pwm_out;
    
    -- set the divider with each cfg tick from the processor
    set_div: process(s00_axi_aclk, pwm_reset)
    begin
        if rising_edge(s00_axi_aclk) then
            pwm_divide <= pwm_divide;
            if pwm_reset = '1' then
                pwm_divide <= (others => '1');
            else
                if cfg_tick = '1' then
                    pwm_divide <= pwm_cfg(C_U_NDIV-1 downto 0);
                end if;
            end if;
        end if;
    end process set_div;
    
    -- handle trigger of the pwm control
    set_trg_reg: process(s00_axi_aclk, pwm_reset)
    begin
        if rising_edge(s00_axi_aclk) then
            if pwm_reset ='1' then
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
    
	-- User logic ends

end arch_imp;

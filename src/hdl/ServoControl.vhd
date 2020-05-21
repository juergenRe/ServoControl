library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ServoControl is
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
end ServoControl;

architecture arch_imp of ServoControl is
    signal pwm_channel:     std_logic_vector(C_U_NC-1 downto 0);
    signal pwm_value:       std_logic_vector(C_U_NP-1 downto 0);
    signal pwm_cfg:         std_logic_vector(C_S00_AXI_DATA_WIDTH -1 downto 0);
    signal cfg_tick:        std_logic;
    signal pwm_out:         std_logic_vector(C_U_NC-1 downto 0);
    signal reset:           std_logic;
    signal rd_data:         std_logic_vector(C_S00_AXI_DATA_WIDTH -1 downto 0);
    signal rd_tick:         std_logic;

	-- component declaration
        -- configuration and control word:
        -- U_CFG(U_C_NDIV-1 downto 0) --> actual prescale value; will be changed with every prescale tick
        -- U_CFG(31) = trg            --> latch new values with falling edge
        -- U_CFG(30) = ONOFF          --> global on/off of all pwm signals
	component ServoControl_S00_AXI is
		generic (
        C_U_NP_AXI          : integer := 16;      -- max bits of precision
        C_U_NC_AXI          : integer := 4;        -- max number of channels
		C_S_AXI_DATA_WIDTH	: integer := 32;
		C_S_AXI_ADDR_WIDTH	: integer := 4
		);
		port (
        U_CHAN          : out std_logic_vector(3 downto 0);
        U_VAL           : out std_logic_vector(C_U_NP_AXI-1 downto 0);
        U_CFG           : out std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
        U_WR_TICK       : out std_logic;
		U_RD_DATA       : in std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
		U_RD_TICK       : in std_logic;

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
	end component ServoControl_S00_AXI;

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
            U_CHAN      : in std_logic_vector(3 downto 0);
            U_VAL       : in std_logic_vector(C_U_NP-1 downto 0);
            -- configuration and control word:
            -- U_CFG(U_C_NDIV-1 downto 0) --> actual prescale value; will be changed with every prescale tick
            -- U_CFG(31) = trg            --> latch new values with falling edge
            -- U_CFG(30) = ONOFF          --> global on/off of all pwm signals
            U_CFG       : in std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
            U_WR_TICK   : in std_logic;
            U_RD_DATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
            U_RD_TICK   : out std_logic;
            pwm_out     : out std_logic_vector(C_U_NC-1 downto 0)
        );
    end component ServoCtrlWrapper;
    
begin

-- Instantiation of Axi Bus Interface S00_AXI
ServoControl_S00_AXI_inst : ServoControl_S00_AXI
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
	    U_WR_TICK       => cfg_tick,
	    U_RD_DATA       => rd_data,
	    U_RD_TICK       => rd_tick,
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
ServoControlWrapper_inst: ServoCtrlWrapper
    generic map(
        C_U_NP              => C_U_NP,       
        C_U_NC              => C_U_NC,
        C_U_NDIV            => C_U_NDIV,
        C_S_AXI_DATA_WIDTH  => C_S00_AXI_DATA_WIDTH
    )
    port map (
	    clk         => s00_axi_aclk,
	    reset       => reset,
        U_CHAN      => pwm_channel,     
        U_VAL       => pwm_value,
        U_CFG       => pwm_cfg,
        U_WR_TICK   => cfg_tick,
	    U_RD_DATA   => rd_data,
	    U_RD_TICK   => rd_tick,
        pwm_out     => pwm_out
    );
    pwmi <= pwm_out;
    reset <= not s00_axi_aresetn;
  
	-- User logic ends

end arch_imp;

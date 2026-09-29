library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb2_axi4_vlan_inserter is
end tb2_axi4_vlan_inserter;

architecture Behavioral of tb2_axi4_vlan_inserter is
    -- Clock & Reset
    signal clk     : std_logic := '0';
    signal rstn    : std_logic := '0';

    -- AXI4-Stream input
    signal s_tvalid : std_logic := '0';
    signal s_tready : std_logic;
    signal s_tdata  : std_logic_vector(63 downto 0) := (others => '0');
    signal s_tkeep  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_tlast  : std_logic := '0';

    -- AXI4-Stream output
    signal m_tvalid : std_logic;
    signal m_tready : std_logic := '1';
    signal m_tdata  : std_logic_vector(63 downto 0);
    signal m_tkeep  : std_logic_vector(7 downto 0);
    signal m_tlast  : std_logic;

    -- AXI4-Lite Interface
    signal awaddr   : std_logic_vector(3 downto 0) := (others => '0');
    signal awvalid  : std_logic := '0';
    signal awready  : std_logic;
    signal wdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal wvalid   : std_logic := '0';
    signal wready   : std_logic;
    signal bresp    : std_logic_vector(1 downto 0);
    signal bvalid   : std_logic;
    signal bready   : std_logic := '0';
    signal araddr   : std_logic_vector(3 downto 0) := (others => '0');
    signal arvalid  : std_logic := '0';
    signal arready  : std_logic;
    signal rdata    : std_logic_vector(31 downto 0);
    signal rresp    : std_logic_vector(1 downto 0);
    signal rvalid   : std_logic;
    signal rready   : std_logic := '0';
begin
    DUT: entity work.axi4_vlan_inserter
        port map(
            aclk          => clk,
            aresetn       => rstn,

            s_axis_tvalid => s_tvalid,
            s_axis_tready => s_tready,
            s_axis_tdata  => s_tdata,
            s_axis_tkeep  => s_tkeep,
            s_axis_tlast  => s_tlast,

            m_axis_tvalid => m_tvalid,
            m_axis_tready => m_tready,
            m_axis_tdata  => m_tdata,
            m_axis_tkeep  => m_tkeep,
            m_axis_tlast  => m_tlast,

            s_axi_awaddr  => awaddr,
            s_axi_awvalid => awvalid,
            s_axi_awready => awready,
            s_axi_wdata   => wdata,
            s_axi_wvalid  => wvalid,
            s_axi_wready  => wready,
            s_axi_bresp   => bresp,
            s_axi_bvalid  => bvalid,
            s_axi_bready  => bready,
            s_axi_araddr  => araddr,
            s_axi_arvalid => arvalid,
            s_axi_arready => arready,
            s_axi_rdata   => rdata,
            s_axi_rresp   => rresp,
            s_axi_rvalid  => rvalid,
            s_axi_rready  => rready
        );
        
        clock : process 
        begin 
            while true loop
                clk <= '0';
                wait for 10ns;
                clk <= '1';
                wait for 10ns;
            end loop;
        end process;
        
        process 
        begin
            rstn <= '0';
            wait for 20 ns;
            rstn <= '1';
            awaddr <= "0100";
            awvalid <= '1';
            wdata <= x"00001000";
            wvalid <= '1';
            
            wait until (awready = '1' and wready = '1') and rising_edge(clk);
            awvalid <= '0';
            wvalid <= '0';
            
            bready <= '1';
            wait until (bvalid = '1') and rising_edge(clk);
            bready <= '0';
            --IDLE STATE (PREAMBLE)
            s_tdata <= x"8765432112345678";
            s_tkeep <= x"FF";
            s_tvalid <= '1';
            s_tlast <= '0';
            wait until s_tready = '1' and rising_edge(clk);
            --COPY HEADER 1 (DEST MAC)
            s_tdata <= x"0099AABBCCDDEEFF";
            s_tkeep <= x"FF";
            s_tlast <= '0';
            wait until s_tready = '1' and rising_edge(clk);
            --COPY HEADER 2 (SRC MAC + VLAN ID)
            s_tdata <= x"1234567800000000";
            s_tkeep <= x"F0";
            s_tlast <= '0';
            wait until s_tready = '1' and rising_edge(clk);
            assert m_tdata(31 downto 0) = x"00001000" report "VLAN ID not inserted correctly!" severity error;
            -- FORWARD PAYLOAD
            s_tdata <= x"1122334455667788";
            s_tkeep <= x"FF";
            s_tlast <= '1';
            wait until s_tready = '1' and rising_edge(clk);
            
            s_tvalid <= '0';
            s_tlast <= '0';
            s_tdata <= "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU";
            wait;
        end process;

end Behavioral;
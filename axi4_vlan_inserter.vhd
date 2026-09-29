library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity axi4_vlan_inserter is
    port (
        aclk        : in  std_logic;
        aresetn     : in  std_logic;
        
        -- AXI4-Stream Slave (Input)
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(63 downto 0);
        s_axis_tkeep  : in  std_logic_vector(7 downto 0);
        s_axis_tlast  : in  std_logic;

        -- AXI4-Stream Master (Output)
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(63 downto 0);
        m_axis_tkeep  : out std_logic_vector(7 downto 0);
        m_axis_tlast  : out std_logic;

        -- AXI4-Lite Slave Interface (Read/Write Register)
        s_axi_awaddr  : in  std_logic_vector(3 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(3 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic
    );
end axi4_vlan_inserter;

architecture Behavioral of axi4_vlan_inserter is

    -- AXI4-Lite registers
    signal reg_vlan_id     : std_logic_vector(31 downto 0) := x"00000001";
    constant REG_VERSION   : std_logic_vector(31 downto 0) := x"00000100";

    -- AXI4-Lite control
    signal axi_awready, axi_wready, axi_bvalid, axi_arready, axi_rvalid : std_logic := '0';
    signal axi_bresp, axi_rresp : std_logic_vector(1 downto 0) := (others => '0');
    signal axi_rdata : std_logic_vector(31 downto 0) := (others => '0');

    -- FSM
    type state_type is (IDLE, COPY_HDR1, COPY_HDR2, FORWARD_PAYLOAD);
    signal state : state_type := IDLE;

    -- Stream internal buffer
    signal data_reg : std_logic_vector(63 downto 0);
    signal keep_reg : std_logic_vector(7 downto 0);
    signal last_reg : std_logic;
    signal axi_tready : std_logic;
    signal byte_count : integer range 0 to 63 := 0;

    -- Output buffering
    signal m_valid, m_last : std_logic := '0';
    signal m_data : std_logic_vector(63 downto 0) := (others => '0');
    signal m_keep : std_logic_vector(7 downto 0) := (others => '0');

begin
    axi_tready <= '1' when (m_axis_tready = '1') else '0';
    s_axis_tready <= axi_tready;
    -- AXI4-Lite Register 
    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bvalid  <= axi_bvalid;
    s_axi_bresp   <= axi_bresp;
    s_axi_arready <= axi_arready;
    s_axi_rvalid  <= axi_rvalid;
    s_axi_rdata   <= axi_rdata;
    s_axi_rresp   <= axi_rresp;
    s_axis_tready <= axi_tready;

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
                axi_arready <= '0';
                axi_rvalid  <= '0';
            else
                -- Write channel
                if s_axi_awvalid = '1' and axi_awready = '0' then
                    axi_awready <= '1';
                else
                    axi_awready <= '0';
                end if;
                
                if s_axi_wvalid = '1' and axi_wready = '0' then
                    axi_wready  <= '1';
                else
                    axi_wready  <= '0';
                end if;
                
                if s_axi_awvalid = '1' and s_axi_wvalid = '1' and axi_awready = '1' and axi_wready = '1' then
                    case s_axi_awaddr is
                        when "0100" =>  -- 0x04 VLAN ID
                            reg_vlan_id <= s_axi_wdata;
                        when others =>
                            null;
                    end case;
                    axi_bvalid <= '1';
                    axi_bresp <= "00";
                elsif s_axi_bready = '1' then
                    axi_bvalid <= '0';
                end if;

                -- Read channel
                if s_axi_arvalid = '1' and axi_arready = '0' then
                    axi_arready <= '1';
                else
                    axi_arready <= '0';
                end if;

                if s_axi_arvalid = '1' and axi_arready = '1' then
                    axi_rvalid <= '1';
                    case s_axi_araddr is
                        when "0000" => axi_rdata <= REG_VERSION;   
                        when "0100" => axi_rdata <= reg_vlan_id;   
                        when others => axi_rdata <= (others => '0');
                    end case;
                    axi_rresp <= "00";
                elsif s_axi_rready = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= IDLE;
                byte_count <= 0;
                m_valid <= '1';
                m_last <= '0';
            else
                m_valid <= '0';
                case state is
                    when IDLE =>
                        if s_axis_tvalid = '1' and axi_tready = '1' then
                            m_data <= s_axis_tdata;
                            m_keep <= s_axis_tkeep;
                            m_valid <= '1';
                            m_last <= '0';
                            byte_count <= 8;
                            state <= COPY_HDR1;
                        end if;

                    when COPY_HDR1 =>
                        if s_axis_tvalid = '1' and axi_tready = '1' then
                            m_data <= s_axis_tdata;
                            m_keep <= s_axis_tkeep;
                            m_valid <= '1';
                            byte_count <= byte_count + 8;
                            state <= COPY_HDR2;
                        end if;

                    when COPY_HDR2 =>
                        if s_axis_tvalid = '1' and axi_tready = '1' then
                            m_data <= s_axis_tdata(63 downto 32) & reg_vlan_id;
                            m_keep <= s_axis_tkeep;
                            m_valid <= '1';
                            byte_count <= byte_count + 8;
                            state <= FORWARD_PAYLOAD;
                        end if;

                    when FORWARD_PAYLOAD =>
                        if s_axis_tvalid = '1' and axi_tready = '1' then
                            m_data <= s_axis_tdata;
                            m_keep <= s_axis_tkeep;
                            m_valid <= '1';
                            m_last <= s_axis_tlast;
                            if s_axis_tlast = '1' then
                                state <= IDLE;
                            end if;
                        end if; 

                    when others => state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    m_axis_tvalid <= m_valid;
    m_axis_tdata  <= m_data;
    m_axis_tkeep  <= m_keep;
    m_axis_tlast  <= m_last;

end Behavioral;

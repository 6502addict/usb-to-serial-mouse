library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serial_write is
    generic (
        CLK_FREQ_HZ     : positive := 50000000;  
        BAUD_RATE       : positive := 9600;      
        OVERSAMPLE_RATE : positive := 16;       
        STOP_BITS       : positive := 2          
    );
    port (
        clk        : in  std_logic;    
        reset_n    : in  std_logic := '1';
        data_in    : in  std_logic_vector(7 downto 0);
        tx         : out std_logic;
        req        : in  std_logic;
        busy       : out std_logic
    );
end entity serial_write;

architecture rtl of serial_write is

    component baud_clock_divider is
        generic (
            CLK_FREQ_HZ     : positive := 50000000;  
            BAUD_RATE       : positive := 115200;
            OVERSAMPLE_RATE : positive := 16
        );
        port (
            clk_in   : in  std_logic;
            reset_n  : in  std_logic;
            baud_out : out std_logic
        );
    end component;
    
    type state_type is (IDLE, START, DATA, STOP);
    signal state : state_type;
    signal bit_counter   : integer range 0 to 7;
    signal cycle_counter : integer range 0 to (OVERSAMPLE_RATE - 1);
    signal stop_counter  : integer range 0 to (STOP_BITS * OVERSAMPLE_RATE - 1);
    signal tx_data : std_logic_vector(7 downto 0);
    signal tx_active : std_logic;
    signal baud_clk : std_logic;
    
begin
    BAUD_GEN: baud_clock_divider
    generic map (
        CLK_FREQ_HZ     => CLK_FREQ_HZ,
        BAUD_RATE       => BAUD_RATE,
        OVERSAMPLE_RATE => OVERSAMPLE_RATE
    )
    port map (
        clk_in   => clk,
        reset_n  => reset_n,
        baud_out => baud_clk
    );
    
    busy <= tx_active;
    process(baud_clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            tx <= '1';           
            tx_active <= '0';
            bit_counter <= 0;
            cycle_counter <= 0;
            stop_counter <= 0;
            
        elsif rising_edge(baud_clk) then
            case state is
                when IDLE =>
                    tx <= '1';    
                    if req = '1' and tx_active = '0' then
                        tx_data <= data_in;
                        tx_active <= '1';
                        state <= START;
                        cycle_counter <= 0;
                    end if;
                    
                when START =>
                    tx <= '0';   
                    if cycle_counter = OVERSAMPLE_RATE - 1 then
                        state <= DATA;
                        cycle_counter <= 0;
                        bit_counter <= 0;
                    else
                        cycle_counter <= cycle_counter + 1;
                    end if;
                    
                when DATA =>
                    tx <= tx_data(bit_counter);
                    if cycle_counter = OVERSAMPLE_RATE - 1 then
                        cycle_counter <= 0;
                        
                        if bit_counter = 7 then
                            state <= STOP;
                            stop_counter <= 0;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                    else
                        cycle_counter <= cycle_counter + 1;
                    end if;
                    
                when STOP =>
                    tx <= '1'; 
                    if stop_counter = (STOP_BITS * OVERSAMPLE_RATE - 1) then
                        state <= IDLE;
                        tx_active <= '0';
                    else
                        stop_counter <= stop_counter + 1;
                    end if;
            end case;
        end if;
    end process;
	 
end architecture rtl;

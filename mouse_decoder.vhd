library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity msmouse_decoder is
    generic (
        MAX_X        : integer := 640;   
        MAX_Y        : integer := 480    
    );
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        data_in        : in  std_logic_vector(7 downto 0);
        strobe_n       : in  std_logic;
        x_pos          : out integer range 0 to MAX_X - 1;  
        y_pos          : out integer range 0 to MAX_Y - 1;  
        left_btn       : out std_logic;
        right_btn      : out std_logic;
        mouse_strobe_n : out std_logic
    );
end entity msmouse_decoder;

architecture rtl of msmouse_decoder is
    type state_type is (WAIT_FIRST, WAIT_SECOND, WAIT_THIRD, UPDATE_OUTPUT);
    signal state : state_type := WAIT_FIRST;
    signal packet_byte1 : std_logic_vector(7 downto 0);
    signal packet_byte2 : std_logic_vector(7 downto 0);
    signal packet_byte3 : std_logic_vector(7 downto 0);
    signal x_movement : signed(7 downto 0);
    signal y_movement : signed(7 downto 0);
    signal x_position : integer range 0 to MAX_X - 1 := MAX_X / 2; 
    signal y_position : integer range 0 to MAX_Y - 1 := MAX_Y / 2; 
    signal l_button : std_logic;
    signal r_button : std_logic;
    signal strobe_prev : std_logic := '1';
    constant SENSITIVITY : integer := 1;
    
begin
    process(clk, reset_n)
        variable new_x_pos : integer;
        variable new_y_pos : integer;
    begin
        if reset_n = '0' then
            state <= WAIT_FIRST;
            x_position     <= MAX_X / 2;
            y_position     <= MAX_Y / 2;
            l_button       <= '0';
            r_button       <= '0';
            mouse_strobe_n <= '1';
            
        elsif rising_edge(clk) then
            mouse_strobe_n <= '1';
            strobe_prev <= strobe_n;
	   -- detect falling edge of strobe_n
            if strobe_prev = '1' and strobe_n = '0' then
                case state is
                    when WAIT_FIRST =>
                        -- first byte has bit 6 set
                        if data_in(6) = '1' then
                            packet_byte1 <= data_in;
                            state <= WAIT_SECOND;
                        end if;
                    
                    when WAIT_SECOND =>
                        packet_byte2 <= data_in;
                        state <= WAIT_THIRD;
                    
                    when WAIT_THIRD =>
                        packet_byte3 <= data_in;
                        state <= UPDATE_OUTPUT;
                    
                    when UPDATE_OUTPUT =>
                        -- Should not reach here directly from strobe
                        null;
                    
                    when others =>
                        state <= WAIT_FIRST;
                end case;
					 
            elsif state = UPDATE_OUTPUT then
                l_button <= packet_byte1(5); 
                r_button <= packet_byte1(4); 
                
                if packet_byte1(1) = '1' then 
                    x_movement <= -signed('0' & packet_byte1(0) & packet_byte1(5 downto 0));
                else
                    x_movement <=  signed('0' & packet_byte1(0) & packet_byte1(5 downto 0));
                end if;
                
                if packet_byte1(3) = '1' then  
                    y_movement <= -signed('0' & packet_byte1(2) & packet_byte2(5 downto 0));
                else
                    y_movement <=  signed('0' & packet_byte1(2) & packet_byte2(5 downto 0));
                end if;
                
                new_x_pos := x_position + (to_integer(x_movement));
                new_y_pos := y_position + (to_integer(y_movement));                
					 
                if new_x_pos < 0 then
                    x_position <= 0;
                elsif new_x_pos >= MAX_X then
                    x_position <= MAX_X - 1;
                else
                    x_position <= new_x_pos;
                end if;
                
                if new_y_pos < 0 then
                    y_position <= 0;
                elsif new_y_pos >= MAX_Y then
                    y_position <= MAX_Y - 1;
                else
                    y_position <= new_y_pos;
                end if;
                
                mouse_strobe_n <= '0';
                state <= WAIT_FIRST;
            end if;
        end if;
    end process;
    
    x_pos     <= x_position;
    y_pos     <= y_position;
    left_btn  <= l_button;
    right_btn <= r_button;
    
end architecture rtl;

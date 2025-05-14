library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
 
entity mouse_receiver is
  generic (
      CPB : integer := 1000000/1200
    );
  port (
    clk      : in  std_logic;
    rx       : in  std_logic;
    strobe_n : out std_logic;
    data_out : out std_logic_vector(7 downto 0)
    );
end mouse_receiver;
 
 
architecture rtl of mouse_receiver is
 
  type uart_state_t is (UART_IDLE, UART_START, UART_DATA, UART_STOP, UART_STROBE);
  signal uart_state : uart_state_t := UART_IDLE;
 
  signal clocks  : integer range 0 to CPB - 1 := 0;
  signal bitno   : integer range 0 to 6 := 0;  
  signal byte    : std_logic_vector(7 downto 0) := (others => '0');
  signal r       : std_logic := '0';
  signal rxd     : std_logic := '0';
   
begin

  sample : process (clk)
  begin
    if rising_edge(clk) then
      r   <= rx;
      rxd <= r; 
    end if; 
  end process;
 
  receive : process (clk)
  begin
    if rising_edge(clk) then
      case uart_state is
        when UART_IDLE =>
          strobe_n <= '1';
          clocks <= 0;
          bitno  <= 0;
          if rxd = '0' then       
            uart_state <= UART_START;
          end if;
 
          when UART_START =>
          if clocks = (CPB-1)/2 then
            if rxd = '0' then
              clocks <= 0;  
              uart_state <= UART_DATA;
            else
              uart_state <= UART_IDLE;
            end if;
          else
            clocks <= clocks + 1;
          end if;
         
        when UART_DATA =>
          if clocks < CPB - 1 then
            clocks <= clocks + 1;
          else
            clocks <= 0;
            byte(bitno) <= rxd;
            if bitno < 6 then
              bitno <= bitno + 1;
            else
              bitno <= 0;
              uart_state <= UART_STOP;
            end if;
          end if;
           
        when UART_STOP =>
          if clocks < CPB-1 then
            clocks <= clocks + 1;
          else
            strobe_n   <= '0';
            clocks <= 0;
            uart_state <= UART_STROBE;
          end if;
            
        when UART_STROBE =>
          uart_state <= UART_IDLE;
          strobe_n <= '1';
			 
        when others =>
          uart_state <= UART_IDLE;
 
      end case;
    end if;
  end process;
 
  data_out <= byte;                    
   
end rtl;

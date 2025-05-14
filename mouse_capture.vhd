library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mouse_capture is
    generic (
        MAX_X           : integer := 640;
        MAX_Y           : integer := 480;
        CLK_FREQ_HZ     : positive := 50000000;  
        BAUD_RATE       : positive := 38400;    
        OVERSAMPLE_RATE : positive := 16;        
        STOP_BITS       : positive := 2
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic := '1';
        x_pos       : in  integer range 0 to MAX_X - 1;
        y_pos       : in  integer range 0 to MAX_Y - 1;
        left_btn    : in  std_logic;
        right_btn   : in  std_logic;
        strobe_n    : in  std_logic := '1';
        tx          : out std_logic
    );
end entity mouse_capture;

architecture rtl of mouse_capture is
    -- Constants for ASCII characters
    constant CR_CHAR    : std_logic_vector(7 downto 0) := X"0D";
    constant LF_CHAR    : std_logic_vector(7 downto 0) := X"0A";
    constant SPACE_CHAR : std_logic_vector(7 downto 0) := X"20";
    constant EQUALS_CHAR : std_logic_vector(7 downto 0) := X"3D"; -- '='
    
    -- Serial writer component
    component serial_write is
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
    end component;
    
    -- State machine for writing to output
    type state_type is (IDLE, CAPTURE,
                        -- Frame number
                        WRITE_DIGIT1, WRITE_DIGIT1A, WRITE_DIGIT2, WRITE_DIGIT2A, 
                        WRITE_DIGIT3, WRITE_DIGIT3A, WRITE_DIGIT4, WRITE_DIGIT4A,
                        WRITE_SPACE1, WRITE_SPACE1A,
                        -- X position
                        WRITE_X, WRITE_XA,
                        WRITE_EQUAL1, WRITE_EQUAL1A,
                        WRITE_X_DIGIT1, WRITE_X_DIGIT1A, 
                        WRITE_X_DIGIT2, WRITE_X_DIGIT2A, 
                        WRITE_X_DIGIT3, WRITE_X_DIGIT3A,
                        WRITE_SPACE2, WRITE_SPACE2A,
                        -- Y position
                        WRITE_Y, WRITE_YA,
                        WRITE_EQUAL2, WRITE_EQUAL2A,
                        WRITE_Y_DIGIT1, WRITE_Y_DIGIT1A, 
                        WRITE_Y_DIGIT2, WRITE_Y_DIGIT2A, 
                        WRITE_Y_DIGIT3, WRITE_Y_DIGIT3A,
                        WRITE_SPACE3, WRITE_SPACE3A,
                        -- Button states
                        WRITE_L, WRITE_LA, WRITE_L_STATE, WRITE_L_STATEA,
                        WRITE_SPACE4, WRITE_SPACE4A,
                        WRITE_R, WRITE_RA, WRITE_R_STATE, WRITE_R_STATEA,
                        -- End of line
                        WRITE_CR, WRITE_CRA, WRITE_LF, WRITE_LFA);
    signal state : state_type := IDLE;
    
    -- For edge detection of strobe_n
    signal req_prev : std_logic := '1';
    
    -- BCD digits for frame counter and positions
    type bcd_digits_type is array (3 downto 0) of std_logic_vector(7 downto 0);
    signal x_bcd_digits : bcd_digits_type;
    signal y_bcd_digits : bcd_digits_type;
    
    -- Serial writer signals
    signal tx_data      : std_logic_vector(7 downto 0);
    signal tx_req       : std_logic := '0';
    signal tx_busy      : std_logic;
    signal serial_tx    : std_logic;
	 
	 signal prev_x       : integer range 0 to MAX_X - 1;
	 signal prev_y       : integer range 0 to MAX_Y - 1;
    signal prev_left    : std_logic := '0';
    signal prev_right   : std_logic := '0';
	 
    -- Convert binary to BCD
    function to_bcd(bin: unsigned(13 downto 0)) return bcd_digits_type is
        variable temp : unsigned(13 downto 0);
        variable bcd : bcd_digits_type;
        variable i : integer;
    begin
        temp := bin;
        bcd(0) := X"30";
        bcd(1) := X"30";
        bcd(2) := X"30";
        bcd(3) := X"30";
        
        for i in 0 to 13 loop
            if unsigned(bcd(3)(3 downto 0)) >= 5 then
                bcd(3)(3 downto 0) := std_logic_vector(unsigned(bcd(3)(3 downto 0)) + 3);
            end if;
            if unsigned(bcd(2)(3 downto 0)) >= 5 then
                bcd(2)(3 downto 0) := std_logic_vector(unsigned(bcd(2)(3 downto 0)) + 3);
            end if;
            if unsigned(bcd(1)(3 downto 0)) >= 5 then
                bcd(1)(3 downto 0) := std_logic_vector(unsigned(bcd(1)(3 downto 0)) + 3);
            end if;
            if unsigned(bcd(0)(3 downto 0)) >= 5 then
                bcd(0)(3 downto 0) := std_logic_vector(unsigned(bcd(0)(3 downto 0)) + 3);
            end if;
            
            bcd(3)(3 downto 0) := bcd(3)(2 downto 0) & bcd(2)(3);
            bcd(2)(3 downto 0) := bcd(2)(2 downto 0) & bcd(1)(3);
            bcd(1)(3 downto 0) := bcd(1)(2 downto 0) & bcd(0)(3);
            bcd(0)(3 downto 0) := bcd(0)(2 downto 0) & temp(13);
            temp := temp(12 downto 0) & '0';
        end loop;
        
        return bcd;
    end function;
    
    -- Convert 10-bit integer to 3-digit BCD
    function int_to_bcd(value: integer) return bcd_digits_type is
        variable temp : unsigned(9 downto 0);
        variable bcd : bcd_digits_type;
        variable i : integer;
    begin
        temp := to_unsigned(value, 10);
        bcd(0) := X"30";
        bcd(1) := X"30";
        bcd(2) := X"30";
        bcd(3) := X"30";
        
        for i in 0 to 9 loop
            if unsigned(bcd(2)(3 downto 0)) >= 5 then
                bcd(2)(3 downto 0) := std_logic_vector(unsigned(bcd(2)(3 downto 0)) + 3);
            end if;
            if unsigned(bcd(1)(3 downto 0)) >= 5 then
                bcd(1)(3 downto 0) := std_logic_vector(unsigned(bcd(1)(3 downto 0)) + 3);
            end if;
            if unsigned(bcd(0)(3 downto 0)) >= 5 then
                bcd(0)(3 downto 0) := std_logic_vector(unsigned(bcd(0)(3 downto 0)) + 3);
            end if;
            
            bcd(2)(3 downto 0) := bcd(2)(2 downto 0) & bcd(1)(3);
            bcd(1)(3 downto 0) := bcd(1)(2 downto 0) & bcd(0)(3);
            bcd(0)(3 downto 0) := bcd(0)(2 downto 0) & temp(9);
            temp := temp(8 downto 0) & '0';
        end loop;
        
        return bcd;
    end function;
    
begin
    -- Instantiate the serial writer directly
    SERIAL_WRITER : serial_write 
        generic map (
            CLK_FREQ_HZ     => CLK_FREQ_HZ,
            BAUD_RATE       => BAUD_RATE,
            OVERSAMPLE_RATE => OVERSAMPLE_RATE,
            STOP_BITS       => STOP_BITS
        )
        port map (
            clk             => clk,
            reset_n         => reset_n,
            data_in         => tx_data,
            tx              => serial_tx,
            req             => tx_req,
            busy            => tx_busy
        );
    
    -- Connect the tx output
    tx <= serial_tx;
    
    
    -- Main state machine for formatting and writing output
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            tx_req     <= '0';
            tx_data    <= (others => '0');
            req_prev   <= '1';
            
        elsif rising_edge(clk) then
          if tx_busy = tx_req then
            case state is
              when IDLE =>
                state <= CAPTURE;
                
              when CAPTURE =>
                x_bcd_digits <= int_to_bcd(x_pos);
                y_bcd_digits <= int_to_bcd(y_pos);
                state <= WRITE_X;
                
              -- Write X=
              when WRITE_X =>
                tx_data <= X"58"; -- 'X'
                tx_req <= '1';
                state <= WRITE_XA;
                
              when WRITE_XA =>
                tx_req <= '0';
                state <= WRITE_EQUAL1;
                
              when WRITE_EQUAL1 =>
                tx_data <= EQUALS_CHAR;
                tx_req <= '1';
                state <= WRITE_EQUAL1A;
                
              when WRITE_EQUAL1A =>
                tx_req <= '0';
                state <= WRITE_X_DIGIT1;
                
              -- Write X position (3 digits)
              when WRITE_X_DIGIT1 =>
                tx_data <= x_bcd_digits(2);
                tx_req <= '1';
                state <= WRITE_X_DIGIT1A;
                
              when WRITE_X_DIGIT1A =>
                tx_req <= '0';
                state <= WRITE_X_DIGIT2;
                
              when WRITE_X_DIGIT2 =>
                tx_data <= x_bcd_digits(1);
                tx_req <= '1';
                state <= WRITE_X_DIGIT2A;
                
              when WRITE_X_DIGIT2A =>
                tx_req <= '0';
                state <= WRITE_X_DIGIT3;
                
              when WRITE_X_DIGIT3 =>
                tx_data <= x_bcd_digits(0);
                tx_req <= '1';
                state <= WRITE_X_DIGIT3A;
                
              when WRITE_X_DIGIT3A =>
                tx_req <= '0';
                state <= WRITE_SPACE2;
						 
              -- Space after X position
              when WRITE_SPACE2 =>
                tx_data <= SPACE_CHAR;
                tx_req <= '1';
                state <= WRITE_SPACE2A;
                
              when WRITE_SPACE2A =>
                tx_req <= '0';
                state <= WRITE_Y;
                
              -- Write Y=
              when WRITE_Y =>
                tx_data <= X"59"; -- 'Y'
                tx_req <= '1';
                state <= WRITE_YA;
                
              when WRITE_YA =>
                tx_req <= '0';
                state <= WRITE_EQUAL2;
                
              when WRITE_EQUAL2 =>
                tx_data <= EQUALS_CHAR;
                tx_req <= '1';
                state <= WRITE_EQUAL2A;
                
              when WRITE_EQUAL2A =>
                tx_req <= '0';
                state <= WRITE_Y_DIGIT1;
                
              -- Write Y position (3 digits)
              when WRITE_Y_DIGIT1 =>
                tx_data <= y_bcd_digits(2);
                tx_req <= '1';
                state <= WRITE_Y_DIGIT1A;
						 
              when WRITE_Y_DIGIT1A =>
                tx_req <= '0';
                state <= WRITE_Y_DIGIT2;
              
              when WRITE_Y_DIGIT2 =>
                tx_data <= y_bcd_digits(1);
                tx_req <= '1';
                state <= WRITE_Y_DIGIT2A;
                
              when WRITE_Y_DIGIT2A =>
                tx_req <= '0';
                state <= WRITE_Y_DIGIT3;
              
              when WRITE_Y_DIGIT3 =>
                tx_data <= y_bcd_digits(0);
                tx_req <= '1';
                state <= WRITE_Y_DIGIT3A;
                
              when WRITE_Y_DIGIT3A =>
                tx_req <= '0';
                state <= WRITE_SPACE3;
						 
              -- Space after Y position
              when WRITE_SPACE3 =>
                tx_data <= SPACE_CHAR;
                tx_req <= '1';
                state <= WRITE_SPACE3A;
                
              when WRITE_SPACE3A =>
                tx_req <= '0';
                state <= WRITE_L;
                
              -- Write left button
              when WRITE_L =>
                tx_data <= X"4C"; -- 'L'
                tx_req <= '1';
                state <= WRITE_LA;
                
              when WRITE_LA =>
                tx_req <= '0';
                state <= WRITE_L_STATE;
                
              when WRITE_L_STATE =>
                -- '0' or '1' ASCII code based on button state
                if left_btn = '0' then
                  tx_data <= X"30";
                else 
                  tx_data <= X"31";
                end if;
                tx_req <= '1';
                state <= WRITE_L_STATEA;
						 
              when WRITE_L_STATEA =>
                tx_req <= '0';
                state <= WRITE_SPACE4;
						 
              -- Space after left button
              when WRITE_SPACE4 =>
                tx_data <= SPACE_CHAR;
                tx_req <= '1';
                state <= WRITE_SPACE4A;
                
              when WRITE_SPACE4A =>
                tx_req <= '0';
                state <= WRITE_R;
                
              -- Write right button
              when WRITE_R =>
                tx_data <= X"52"; -- 'R'
                tx_req <= '1';
                state <= WRITE_RA;
                
              when WRITE_RA =>
                tx_req <= '0';
                state <= WRITE_R_STATE;
                
              when WRITE_R_STATE =>
                -- '0' or '1' ASCII code based on button state
                if right_btn = '0' then
                  tx_data <= X"30";
                else 
                  tx_data <= X"31";
                end if;
                tx_req <= '1';
                state <= WRITE_R_STATEA;
                
              when WRITE_R_STATEA =>
                tx_req <= '0';
                state <= WRITE_CR;
                
              -- Write CR (Carriage Return)
              when WRITE_CR =>
                tx_data <= CR_CHAR;
                tx_req <= '1';
                state <= WRITE_CRA;
						 
              when WRITE_CRA =>
                tx_req <= '0';
                state <= IDLE; --WRITE_LF;
						 
              -- Write LF (Line Feed)
              when WRITE_LF =>
                tx_data <= LF_CHAR;
                tx_req <= '1';
                state <= WRITE_LFA;
                
            when WRITE_LFA =>
                tx_req <= '0';
                state <= IDLE;
                
              when others =>
                state <= IDLE;
                tx_req <= '0';
            end case;
          end if;
        end if;
    end process;
    
end architecture rtl;

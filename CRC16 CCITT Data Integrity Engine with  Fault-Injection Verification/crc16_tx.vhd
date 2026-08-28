--------------------------------------------------------------------------------
-- File        : crc16_tx.vhd
-- Description : The SENDER.
--
--               Streams the message out one byte per clock, computing the CRC
--               as it goes, then appends the two CRC bytes at the end.
--
--                 Frame sent = 'H' 'E' 'L' 'L' 'O' CRC_hi CRC_lo
--                            = 48   45   4C   4C   4F   49     D6
--
--               Built as a two-process MOORE state machine. Outputs depend
--               only on the current state and the registers, never directly
--               on the inputs.
--
--               The message lives in this file (byte_array_t and MSG are
--               declared in the architecture), so no package is needed.
--
-- Target      : Xilinx ISE 14.7, VHDL-93
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity crc16_tx is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;                     -- synchronous, active high
    start     : in  std_logic;                     -- pulse to send a frame

    out_data  : out std_logic_vector(7 downto 0);  -- frame byte going out
    out_vld   : out std_logic;                     -- '1' = this byte is real
    out_last  : out std_logic;                     -- '1' = final byte of frame
    busy      : out std_logic;
    done      : out std_logic
  );
end entity crc16_tx;


architecture rtl of crc16_tx is

  ------------------------------------------------------------------------------
  -- The message (was previously in the package)
  ------------------------------------------------------------------------------
  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant MSG     : byte_array_t := (x"48", x"45", x"4C", x"4C", x"4F"); -- "HELLO"
  constant MSG_LEN : integer := MSG'length;                              -- 5

  ------------------------------------------------------------------------------
  -- State machine
  ------------------------------------------------------------------------------
  type state_t is (S_IDLE, S_INIT, S_DATA, S_CRC_HI, S_CRC_LO, S_DONE);
  signal state, next_state : state_t;

  signal idx : integer range 0 to MSG_LEN - 1 := 0;   -- which message byte

  ------------------------------------------------------------------------------
  -- Wires to the CRC engine
  ------------------------------------------------------------------------------
  signal core_init : std_logic;
  signal core_vld  : std_logic;
  signal core_data : std_logic_vector(7 downto 0);
  signal crc_val   : std_logic_vector(15 downto 0);

begin

  ------------------------------------------------------------------------------
  -- CRC engine
  ------------------------------------------------------------------------------
  u_core : entity work.crc16_core
    port map (
      clk      => clk,
      rst      => rst,
      init     => core_init,
      data_in  => core_data,
      data_vld => core_vld,
      crc_out  => crc_val
    );

  ------------------------------------------------------------------------------
  -- Process 1 of 2 : registers (sequential)
  ------------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        idx   <= 0;
      else
        state <= next_state;

        if state = S_IDLE or state = S_INIT then
          idx <= 0;
        elsif state = S_DATA and idx < MSG_LEN - 1 then
          idx <= idx + 1;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Process 2 of 2 : next state and outputs (combinational)
  ------------------------------------------------------------------------------
  process (state, start, idx, crc_val)
  begin
    -- defaults, so nothing is ever left unassigned
    next_state <= state;
    out_data   <= (others => '0');
    out_vld    <= '0';
    out_last   <= '0';
    busy       <= '1';
    done       <= '0';
    core_init  <= '0';
    core_vld   <= '0';
    core_data  <= (others => '0');

    case state is

      -- waiting for a start pulse
      when S_IDLE =>
        busy <= '0';
        if start = '1' then
          next_state <= S_INIT;
        end if;

      -- one clock to reload the CRC engine with 0xFFFF
      when S_INIT =>
        core_init  <= '1';
        next_state <= S_DATA;

      -- send message bytes; each one also goes into the CRC engine
      when S_DATA =>
        out_data  <= MSG(idx);
        out_vld   <= '1';
        core_data <= MSG(idx);
        core_vld  <= '1';
        if idx = MSG_LEN - 1 then
          next_state <= S_CRC_HI;
        end if;

      -- crc_val now covers the whole message.
      -- NOTE: core_vld stays '0' here. The CRC bytes must NOT be fed back
      -- into our own engine, or the appended value would be wrong.
      when S_CRC_HI =>
        out_data   <= crc_val(15 downto 8);
        out_vld    <= '1';
        next_state <= S_CRC_LO;

      when S_CRC_LO =>
        out_data   <= crc_val(7 downto 0);
        out_vld    <= '1';
        out_last   <= '1';
        next_state <= S_DONE;

      when S_DONE =>
        done       <= '1';
        busy       <= '0';
        next_state <= S_IDLE;

      when others =>
        next_state <= S_IDLE;

    end case;
  end process;

end architecture rtl;

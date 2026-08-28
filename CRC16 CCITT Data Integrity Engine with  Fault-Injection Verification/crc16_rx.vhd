--------------------------------------------------------------------------------
-- File        : crc16_rx.vhd
-- Description : The RECEIVER.
--
--               It runs the CRC over the WHOLE incoming frame, message bytes
--               AND the two appended CRC bytes.
--
--               Because CRC-16/CCITT-FALSE has no final XOR, a clean frame is
--               guaranteed to leave 0x0000 behind. Anything else means the
--               data was damaged.
--
--               So the receiver never stores the sender's CRC and never
--               compares two numbers. It only asks: did I land on zero?
--
-- Target      : Xilinx ISE 14.7, VHDL-93
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity crc16_rx is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                     -- synchronous, active high
    start      : in  std_logic;                     -- arm the receiver

    in_data    : in  std_logic_vector(7 downto 0);  -- incoming frame byte
    in_vld     : in  std_logic;
    in_last    : in  std_logic;                     -- final byte of frame

    residue    : out std_logic_vector(15 downto 0); -- 0x0000 if frame is clean
    crc_ok     : out std_logic;                     -- read it when frame_done = '1'
    crc_err    : out std_logic;
    frame_done : out std_logic                      -- '1' = verdict is ready NOW
  );
end entity crc16_rx;


architecture rtl of crc16_rx is

  -- A clean frame must leave exactly this value behind.
  constant CRC_RESIDUE : std_logic_vector(15 downto 0) := x"0000";

  type state_t is (S_IDLE, S_INIT, S_RUN, S_SETTLE, S_DONE);
  signal state, next_state : state_t;

  signal core_init : std_logic;
  signal core_vld  : std_logic;
  signal crc_val   : std_logic_vector(15 downto 0);

  signal ok_reg    : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  -- CRC engine (exactly the same block the sender uses)
  ------------------------------------------------------------------------------
  u_core : entity work.crc16_core
    port map (
      clk      => clk,
      rst      => rst,
      init     => core_init,
      data_in  => in_data,
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
        state  <= S_IDLE;
        ok_reg <= '0';
      else
        -- In S_SETTLE the engine has finished the last byte, so crc_val is
        -- the final residue. Latch the verdict here.
        if state = S_SETTLE then
          if crc_val = CRC_RESIDUE then
            ok_reg <= '1';
          else
            ok_reg <= '0';
          end if;
        end if;

        state <= next_state;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Process 2 of 2 : next state and outputs (combinational)
  ------------------------------------------------------------------------------
  process (state, start, in_vld, in_last)
  begin
    next_state <= state;
    core_init  <= '0';
    core_vld   <= '0';
    frame_done <= '0';

    case state is

      when S_IDLE =>
        if start = '1' then
          next_state <= S_INIT;
        end if;

      -- one clock to reload the CRC engine with 0xFFFF
      when S_INIT =>
        core_init  <= '1';
        next_state <= S_RUN;

      -- swallow every valid byte, including the two CRC bytes
      when S_RUN =>
        core_vld <= in_vld;
        if in_vld = '1' and in_last = '1' then
          next_state <= S_SETTLE;
        end if;

      -- one clock for the last CRC update to land in the register
      when S_SETTLE =>
        next_state <= S_DONE;

      when S_DONE =>
        frame_done <= '1';
        next_state <= S_IDLE;

      when others =>
        next_state <= S_IDLE;

    end case;
  end process;

  residue <= crc_val;
  crc_ok  <= ok_reg;
  crc_err <= not ok_reg;

end architecture rtl;

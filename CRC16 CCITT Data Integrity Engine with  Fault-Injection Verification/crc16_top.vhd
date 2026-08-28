--------------------------------------------------------------------------------
-- File        : crc16_top.vhd
-- Description : Top level. Wires the three blocks into a complete link.
--
--                  +--------+     +---------+     +--------+
--        start --> | SENDER | --> | CHANNEL | --> | RECVR  | --> crc_ok
--                  |   TX   |     | (noise) |     |   RX   |     crc_err
--                  +--------+     +---------+     +--------+
--
--               The CHANNEL is a deliberate fault injector. When
--               inject_en = '1' it XORs err_mask into the byte sitting at
--               position err_index, simulating a damaged link.
--
--               This is what turns the project from an arithmetic exercise
--               into a proven error-detection system: a checksum you never
--               break is a checksum you never tested.
--
-- Target      : Xilinx ISE 14.7, VHDL-93
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity crc16_top is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    start      : in  std_logic;                     -- pulse to run one frame

    -- fault injection controls
    inject_en  : in  std_logic;                     -- '1' = damage a byte
    err_index  : in  integer range 0 to 15;         -- which byte to damage
    err_mask   : in  std_logic_vector(7 downto 0);  -- which bits to flip

    -- observation
    tx_byte    : out std_logic_vector(7 downto 0);  -- byte leaving the sender
    rx_byte    : out std_logic_vector(7 downto 0);  -- byte reaching the receiver
    byte_vld   : out std_logic;                     -- '1' = a real byte moving
    residue    : out std_logic_vector(15 downto 0);
    crc_ok     : out std_logic;
    crc_err    : out std_logic;
    frame_done : out std_logic
  );
end entity crc16_top;


architecture rtl of crc16_top is

  signal t_data : std_logic_vector(7 downto 0);
  signal t_vld  : std_logic;
  signal t_last : std_logic;

  signal c_data : std_logic_vector(7 downto 0);
  signal bcnt   : integer range 0 to 15 := 0;   -- position within the frame

begin

  ------------------------------------------------------------------------------
  -- SENDER
  ------------------------------------------------------------------------------
  u_tx : entity work.crc16_tx
    port map (
      clk      => clk,
      rst      => rst,
      start    => start,
      out_data => t_data,
      out_vld  => t_vld,
      out_last => t_last,
      busy     => open,
      done     => open
    );

  ------------------------------------------------------------------------------
  -- CHANNEL : count which byte of the frame is passing
  ------------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or start = '1' then
        bcnt <= 0;
      elsif t_vld = '1' and bcnt < 15 then
        bcnt <= bcnt + 1;
      end if;
    end if;
  end process;

  -- Damage the chosen byte, pass every other byte through untouched.
  c_data <= (t_data xor err_mask)
            when (inject_en = '1' and bcnt = err_index)
            else t_data;

  ------------------------------------------------------------------------------
  -- RECEIVER
  ------------------------------------------------------------------------------
  u_rx : entity work.crc16_rx
    port map (
      clk        => clk,
      rst        => rst,
      start      => start,
      in_data    => c_data,
      in_vld     => t_vld,
      in_last    => t_last,
      residue    => residue,
      crc_ok     => crc_ok,
      crc_err    => crc_err,
      frame_done => frame_done
    );

  ------------------------------------------------------------------------------
  -- Observation taps
  ------------------------------------------------------------------------------
  tx_byte  <= t_data;
  rx_byte  <= c_data;
  byte_vld <= t_vld;

end architecture rtl;

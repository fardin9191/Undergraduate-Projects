--------------------------------------------------------------------------------
-- File        : crc16_core.vhd
-- Description : The CRC-16 calculating engine. This is the only file that
--               contains any CRC mathematics.
--
--               Feed it one byte per clock while data_vld = '1'.
--               Pulse init for one clock to restart before a new frame.
--
--               Everything it needs (polynomial, start value, the update
--               function) is declared inside its own architecture, so this
--               file depends on nothing else.
--
-- Standard    : CRC-16/CCITT-FALSE
--                 Polynomial  : x^16 + x^12 + x^5 + 1  ->  0x1021
--                 Start value : 0xFFFF
--                 Final XOR   : none
--
-- Target      : Xilinx ISE 14.7, VHDL-93
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity crc16_core is
  port (
    clk      : in  std_logic;                      -- system clock
    rst      : in  std_logic;                      -- synchronous, active high
    init     : in  std_logic;                      -- reload the start value
    data_in  : in  std_logic_vector(7 downto 0);   -- byte to absorb
    data_vld : in  std_logic;                      -- '1' = absorb data_in now
    crc_out  : out std_logic_vector(15 downto 0)   -- running CRC
  );
end entity crc16_core;


architecture rtl of crc16_core is

  ------------------------------------------------------------------------------
  -- Constants (were previously in the package)
  ------------------------------------------------------------------------------
  constant CRC_POLY : std_logic_vector(15 downto 0) := x"1021";
  constant CRC_INIT : std_logic_vector(15 downto 0) := x"FFFF";

  ------------------------------------------------------------------------------
  -- crc16_byte : advance the CRC by one byte.
  --
  -- This is a FUNCTION, not a process. There is no clock inside it, so the
  -- eight loop iterations do NOT take eight clock cycles. XST makes eight
  -- copies of the shift-and-XOR logic and chains them, so a whole byte is
  -- absorbed in a single clock.
  ------------------------------------------------------------------------------
  function crc16_byte (crc_in  : std_logic_vector(15 downto 0);
                       data_in : std_logic_vector(7 downto 0))
                       return std_logic_vector is
    variable crc : std_logic_vector(15 downto 0);
  begin
    -- Mix the new byte into the top half of the register.
    crc := crc_in xor (data_in & x"00");

    -- Eight plain shift-left steps. Whenever a '1' falls off the top,
    -- fold the polynomial back in.
    for i in 0 to 7 loop
      if crc(15) = '1' then
        crc := (crc(14 downto 0) & '0') xor CRC_POLY;
      else
        crc := crc(14 downto 0) & '0';
      end if;
    end loop;

    return crc;
  end function crc16_byte;

  ------------------------------------------------------------------------------
  signal crc_reg : std_logic_vector(15 downto 0) := CRC_INIT;

begin

  ------------------------------------------------------------------------------
  -- The CRC accumulator. Priority: reset, then init, then data.
  ------------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        crc_reg <= CRC_INIT;
      elsif init = '1' then
        crc_reg <= CRC_INIT;
      elsif data_vld = '1' then
        crc_reg <= crc16_byte(crc_reg, data_in);
      end if;
    end if;
  end process;

  crc_out <= crc_reg;

end architecture rtl;

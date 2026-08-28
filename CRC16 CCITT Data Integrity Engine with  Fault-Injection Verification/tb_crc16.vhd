--------------------------------------------------------------------------------
-- File        : tb_crc16.vhd
-- Description : Self-checking testbench. One design under test: crc16_top.
--
--               TEST 1  : clean frame  -> residue 0x0000, crc_ok = '1'
--               TEST 1b : the CRC the sender appended must be 0x49D6
--                         (the correct CRC-16/CCITT-FALSE of "HELLO")
--               TEST 2  : one bit flipped in a message byte -> crc_err = '1'
--               TEST 3  : one bit flipped in the CRC field  -> crc_err = '1'
--               TEST 4  : whole byte destroyed              -> crc_err = '1'
--               TEST 5  : clean frame again, proving the link recovers
--
--               A PASS or FAIL line is printed for each test, so you do not
--               have to read the waveform by eye.
--
-- Target      : Xilinx ISE 14.7 / ISim, VHDL-93
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_crc16 is
end entity tb_crc16;


architecture bench of tb_crc16 is

  constant CLK_PERIOD : time := 10 ns;   -- 100 MHz

  ------------------------------------------------------------------------------
  -- Signals wired to the design
  ------------------------------------------------------------------------------
  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';

  signal b_start   : std_logic := '0';
  signal b_inj     : std_logic := '0';
  signal b_erridx  : integer range 0 to 15 := 0;
  signal b_errmask : std_logic_vector(7 downto 0) := (others => '0');

  signal b_txbyte  : std_logic_vector(7 downto 0);
  signal b_rxbyte  : std_logic_vector(7 downto 0);
  signal b_bvld    : std_logic;
  signal b_residue : std_logic_vector(15 downto 0);
  signal b_ok      : std_logic;
  signal b_err     : std_logic;
  signal b_done    : std_logic;

  ------------------------------------------------------------------------------
  -- Frame recorder: captures every byte the sender puts out, so we can check
  -- that the appended CRC really is 0x49D6.
  ------------------------------------------------------------------------------
  type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
  signal cap     : byte_array_t(0 to 6) := (others => (others => '0'));
  signal cap_idx : integer range 0 to 7 := 0;

  ------------------------------------------------------------------------------
  signal errors : integer := 0;

  ------------------------------------------------------------------------------
  -- Small helpers so the reports print readable hex.
  ------------------------------------------------------------------------------
  function to_hex_char (n : integer) return character is
    constant HEXTAB : string(1 to 16) := "0123456789ABCDEF";
  begin
    return HEXTAB(n + 1);
  end function to_hex_char;

  function hex2 (v : std_logic_vector(7 downto 0)) return string is
    variable s : string(1 to 2);
    variable u : unsigned(7 downto 0);
  begin
    u := unsigned(v);
    s(1) := to_hex_char(to_integer(u(7 downto 4)));
    s(2) := to_hex_char(to_integer(u(3 downto 0)));
    return s;
  end function hex2;

  function hex4 (v : std_logic_vector(15 downto 0)) return string is
    variable s : string(1 to 4);
    variable u : unsigned(15 downto 0);
  begin
    u := unsigned(v);
    s(1) := to_hex_char(to_integer(u(15 downto 12)));
    s(2) := to_hex_char(to_integer(u(11 downto  8)));
    s(3) := to_hex_char(to_integer(u( 7 downto  4)));
    s(4) := to_hex_char(to_integer(u( 3 downto  0)));
    return s;
  end function hex4;

begin

  ------------------------------------------------------------------------------
  -- Clock
  ------------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  ------------------------------------------------------------------------------
  -- Design under test
  ------------------------------------------------------------------------------
  dut : entity work.crc16_top
    port map (
      clk        => clk,
      rst        => rst,
      start      => b_start,
      inject_en  => b_inj,
      err_index  => b_erridx,
      err_mask   => b_errmask,
      tx_byte    => b_txbyte,
      rx_byte    => b_rxbyte,
      byte_vld   => b_bvld,
      residue    => b_residue,
      crc_ok     => b_ok,
      crc_err    => b_err,
      frame_done => b_done
    );

  ------------------------------------------------------------------------------
  -- Frame recorder
  ------------------------------------------------------------------------------
  mon : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or b_start = '1' then
        cap_idx <= 0;
      elsif b_bvld = '1' and cap_idx < 7 then
        cap(cap_idx) <= b_txbyte;
        cap_idx      <= cap_idx + 1;
      end if;
    end if;
  end process mon;

  ------------------------------------------------------------------------------
  -- Test sequence
  ------------------------------------------------------------------------------
  stim : process

    ----------------------------------------------------------------------------
    procedure check (name : string; cond : boolean; info : string) is
    begin
      if cond then
        report "PASS : " & name & "  [" & info & "]" severity note;
      else
        report "FAIL : " & name & "  [" & info & "]" severity error;
        errors <= errors + 1;
      end if;
      wait for 0 ns;
    end procedure check;

    ----------------------------------------------------------------------------
    -- Run one frame with the given fault settings, then wait for the verdict.
    ----------------------------------------------------------------------------
    procedure run_link (inj  : std_logic;
                        idx  : integer;
                        mask : std_logic_vector(7 downto 0)) is
    begin
      b_inj     <= inj;
      b_erridx  <= idx;
      b_errmask <= mask;

      wait until rising_edge(clk);
      b_start <= '1';
      wait until rising_edge(clk);
      b_start <= '0';

      wait until b_done = '1';
      wait until rising_edge(clk);
    end procedure run_link;

  begin
    report "=========== CRC-16/CCITT-FALSE testbench ===========" severity note;

    -- reset
    rst <= '1';
    wait for 4 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 2 * CLK_PERIOD;

    ----------------------------------------------------------------------------
    -- TEST 1 : clean frame
    ----------------------------------------------------------------------------
    run_link('0', 0, x"00");

    check("T1  clean frame accepted",
          b_ok = '1' and b_residue = x"0000",
          "residue 0x" & hex4(b_residue));

    check("T1b appended CRC = 0x49D6",
          cap(5) = x"49" and cap(6) = x"D6",
          "sent 0x" & hex2(cap(5)) & hex2(cap(6)));

    ----------------------------------------------------------------------------
    -- TEST 2 : flip the lowest bit of message byte 0
    ----------------------------------------------------------------------------
    run_link('1', 0, x"01");
    check("T2  1-bit error in payload detected",
          b_err = '1',
          "residue 0x" & hex4(b_residue));

    ----------------------------------------------------------------------------
    -- TEST 3 : flip the top bit of the CRC low byte (frame byte 6)
    ----------------------------------------------------------------------------
    run_link('1', 6, x"80");
    check("T3  1-bit error in CRC field detected",
          b_err = '1',
          "residue 0x" & hex4(b_residue));

    ----------------------------------------------------------------------------
    -- TEST 4 : invert every bit of message byte 2
    ----------------------------------------------------------------------------
    run_link('1', 2, x"FF");
    check("T4  8-bit burst error detected",
          b_err = '1',
          "residue 0x" & hex4(b_residue));

    ----------------------------------------------------------------------------
    -- TEST 5 : clean again, to prove the link recovers
    ----------------------------------------------------------------------------
    run_link('0', 0, x"00");
    check("T5  link recovers after errors",
          b_ok = '1' and b_residue = x"0000",
          "residue 0x" & hex4(b_residue));

    ----------------------------------------------------------------------------
    wait for 5 * CLK_PERIOD;
    report "====================================================" severity note;
    if errors = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "TESTS FAILED : " & integer'image(errors) severity error;
    end if;
    report "====================================================" severity note;

    wait;
  end process stim;

end architecture bench;

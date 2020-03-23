--
--  OPM_JT51.vhd
--
--    OPM JT51 is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    Author Kunihiko Ohnaka
--
library	IEEE;

use	IEEE.STD_LOGIC_1164.ALL;
use	IEEE.STD_LOGIC_ARITH.ALL;
use	IEEE.STD_LOGIC_UNSIGNED.ALL;

-- OPM.vhdと同じインターフェースで、実装として JT51を使用する
-- コンポーネントです

entity OPM_JT51 is
    generic(
        res		:integer	:=9
    );
    port(
        DIN		:in std_logic_vector(7 downto 0);
        DOUT	:out std_logic_vector(7 downto 0);
        DOE		:out std_logic;
        CSn		:in std_logic;
        ADR0	:in std_logic;
        RDn		:in std_logic;
        WRn		:in std_logic;
        INTn	:out std_logic;
        
        sndL	:out std_logic_vector(res-1 downto 0);
        sndR	:out std_logic_vector(res-1 downto 0);
        
        CT1		:out std_logic;
        CT2		:out std_logic;
        
        chenable:in std_logic_vector(7 downto 0)	:=(others=>'1');
        monout	:out std_logic_vector(15 downto 0);
        op0out	:out std_logic_vector(15 downto 0);
        op1out	:out std_logic_vector(15 downto 0);
        op2out	:out std_logic_vector(15 downto 0);
        op3out	:out std_logic_vector(15 downto 0);
    
        fmclk	:in std_logic;
        pclk	:in std_logic;
        rstn	:in std_logic
    );
end OPM_JT51;
    
architecture rtl of OPM_JT51 is

-- JT51 Verilog module definition is below:
--
-- module jt51(
--    input               rst,    // reset
--    input               clk,    // main clock
--    input               cen,    // clock enable
--    input               cen_p1, // clock enable at half the speed
--    input               cs_n,   // chip select
--    input               wr_n,   // write
--    input               a0,
--    input       [7:0]   din, // data in
--    output      [7:0]   dout, // data out
--    // peripheral control
--    output              ct1,
--    output              ct2,
--    output              irq_n,  // I do not synchronize this signal
--    // Low resolution output (same as real chip)
--    output              sample, // marks new output sample
--    output  signed  [15:0] left,
--    output  signed  [15:0] right,
--    // Full resolution output
--    output  signed  [15:0] xleft,
--    output  signed  [15:0] xright,
--    // unsigned outputs for sigma delta converters, full resolution
--    output  [15:0] dacleft,
--    output  [15:0] dacright
--);

component jt51
port(
	rst		:in std_logic;
	clk		:in std_logic;
    cen		:in std_logic;
    cen_p1  :in std_logic;
    cs_n    :in std_logic;
    wr_n    :in std_logic;
    a0      :in std_logic;
    din     :in std_logic_vector(7 downto 0);
    dout    :out std_logic_vector(7 downto 0);
    -- peripheral control
    ct1     :out std_logic;
    ct2     :out std_logic;
    irq_n   :out std_logic;
    -- Low resolution output (same as real chip)
    sample  :out std_logic;
    left    :out std_logic_vector(15 downto 0); --signed
    right   :out std_logic_vector(15 downto 0); --signed
    -- Full resolution output
    xleft   :out std_logic_vector(15 downto 0); --signed
    xright  :out std_logic_vector(15 downto 0); --signed
    -- unsigned outputes for sigma delta converters, full resolution
    dacleft :out std_logic_vector(15 downto 0); --unsigned
    dacright :out std_logic_vector(15 downto 0) --unsigned
);
end component;

signal jt51_cen     : std_logic;
signal jt51_cen_p1  : std_logic;
signal jt51_cs_n    : std_logic;
signal jt51_wr_n    : std_logic;
signal jt51_a0      : std_logic;
signal jt51_din     : std_logic_vector(7 downto 0);
signal jt51_dout    : std_logic_vector(7 downto 0);
signal jt51_ct1     : std_logic;
signal jt51_ct2     : std_logic;
signal jt51_irq_n   : std_logic;
signal jt51_xleft   : std_logic_vector(15 downto 0);
signal jt51_xright  : std_logic_vector(15 downto 0);

signal irq_n_d      : std_logic;
signal din_latch    : std_logic_vector(7 downto 0);

signal divider      : std_logic_vector(3 downto 0); -- 32MHz → 4MHz → 2MHz

signal cs_req       : std_logic;
signal cs_req_d     : std_logic;
signal cs_ack       : std_logic;
signal cs_ack_d     : std_logic;

signal CSn_d       : std_logic;
begin

    jt51_u0 :jt51 port map(
        rst	    => not rstn,
        clk		=> fmclk,
        cen		=> jt51_cen,
        cen_p1  => jt51_cen_p1,
        cs_n    => jt51_cs_n,
        wr_n    => jt51_wr_n,
        a0      => jt51_a0,
        din     => jt51_din,
        dout    => jt51_dout,
        -- peripheral control
        ct1     => jt51_ct1,
        ct2     => jt51_ct2,
        irq_n   => jt51_irq_n,
        -- Low resolution output (same as real chip)
        sample  => open,
        left    => open,
        right   => open,
        -- Full resolution output
        xleft   => jt51_xleft,
        xright  => jt51_xright,
        -- unsigned outputes for sigma delta converters, full resolution
        dacleft => open,
        dacright => open
    );

    -- data bus
    DOUT <= jt51_dout;
    DOE <='1' when CSn='0' and RDn='0' else '0';

    jt51_din <= din_latch;
    jt51_a0  <= ADR0;

    CT1 <= jt51_ct1;
    CT2 <= jt51_ct2;

    monout <= (others => '0');
    op0out <= (others => '0');
    op1out <= (others => '0');
    op2out <= (others => '0');
    op3out <= (others => '0');

    -- fmclk(sndclk) synchronized signals (can be connected directly)
    sndL <= jt51_xleft(15 downto (16 - res));
    sndR <= jt51_xright(15 downto (16 - res));

    -- sysclk synchronized inputs
    process(pclk,rstn)begin
        if(rstn='0')then
            CSn_d <= '1';
            cs_ack_d <= '0';
            din_latch <= (others => '0');
            cs_req <= '0';
        elsif(pclk' event and pclk='1')then
            CSn_d <= CSn;
            cs_ack_d <= cs_ack;
            if( CSn_d = '1' and CSn = '0') then
                din_latch <= DIN;
                cs_req <= not cs_ack_d;
            end if;
        end if;
    end process;

    -- sysclk synchronized outputs
    process(pclk,rstn)begin
        if(rstn='0')then
            irq_n_d <= '1';
            INTn <= '1';
        elsif(pclk' event and pclk='1')then
            irq_n_d <= jt51_irq_n;
            INTn <= irq_n_d;
        end if;
    end process;

    -- fmclk synchronized
    process(fmclk,rstn)begin
        if(rstn='0')then
            jt51_cs_n <= '1';
            jt51_wr_n <= '1'; 
            cs_req_d <= '0';
            cs_ack <= '0';
        elsif(fmclk' event and fmclk='1')then
            jt51_cs_n <= '1';
            jt51_wr_n <= '1';
            cs_req_d <= cs_req; -- メタステーブル回避
            if(cs_req_d /= cs_ack) then
                cs_ack <= cs_req_d;
                jt51_cs_n <= '0';
                jt51_wr_n <= WRn;
            end if;

        end if;
    end process;

    -- fmclk enable
    process(fmclk,rstn)begin
        if(rstn='0')then
            jt51_cen    <= '0';
            jt51_cen_p1 <= '0';
            divider <= (others => '0');
        elsif(fmclk' event and fmclk='1')then
            divider <= divider + 1;

            jt51_cen    <= '0';
            jt51_cen_p1 <= '0';
            if(divider = 0)then
                jt51_cen    <= '1';
                jt51_cen_p1 <= '1';
            elsif(divider = 8)then
                jt51_cen    <= '1';
            end if;
        end if;
    end process;

end rtl;
    
    
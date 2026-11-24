`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import fifo_cfg_pkg::*;
  import fifo_pkg::*;

  // change ratio to test other clock relationships
  localparam real WPER = 10.0, RPER = 7.0;

  logic wclk = 0, rclk = 0, wrst_n = 0, rrst_n = 0;
  always #(WPER/2) wclk = ~wclk;
  always #(RPER/2) rclk = ~rclk;
  initial begin #55 wrst_n = 1; end
  initial begin #63 rrst_n = 1; end

  wr_if wif (wclk, wrst_n);
  rd_if rif (rclk, rrst_n);

  async_fifo #(DATA_W, DEPTH) dut (
    .wclk(wclk), .wrst_n(wrst_n), .winc(wif.winc), .wdata(wif.wdata), .wfull(wif.wfull),
    .rclk(rclk), .rrst_n(rrst_n), .rinc(rif.rinc), .rdata(rif.rdata), .rempty(rif.rempty)
  );

  // CDC / Gray-code assertions
  bind async_fifo async_fifo_sva #(.ADDR_W(ADDR_W)) u_sva (.*);

  initial begin
    uvm_config_db#(virtual wr_if)::set(null, "*", "wvif", wif);
    uvm_config_db#(virtual rd_if)::set(null, "*", "rvif", rif);
    run_test();
  end
endmodule

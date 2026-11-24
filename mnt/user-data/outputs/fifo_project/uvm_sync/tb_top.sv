`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sync_cfg_pkg::*;
  import sync_pkg::*;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  initial #43 rst_n = 1;

  sync_if vif (clk, rst_n);

  sync_fifo #(DATA_W, DEPTH) dut (
    .clk(clk), .rst_n(rst_n),
    .wr_en(vif.wr_en), .wdata(vif.wdata), .rd_en(vif.rd_en),
    .rdata(vif.rdata), .full(vif.full), .empty(vif.empty), .count(vif.count)
  );

  initial begin
    uvm_config_db#(virtual sync_if)::set(null, "*", "vif", vif);
    run_test("sync_test");
  end
endmodule

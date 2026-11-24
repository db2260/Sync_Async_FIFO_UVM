interface sync_if (input logic clk, input logic rst_n);
  import sync_cfg_pkg::*;
  logic              wr_en, rd_en;
  logic [DATA_W-1:0] wdata, rdata;
  logic              full, empty;
  logic [ADDR_W:0]   count;
  initial begin wr_en = 0; rd_en = 0; wdata = '0; end

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output wr_en, rd_en, wdata;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;          // pre-edge values
    input wr_en, rd_en, wdata, rdata, full, empty, count;
  endclocking
endinterface

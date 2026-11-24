interface wr_if (input logic wclk, input logic wrst_n);
  import fifo_cfg_pkg::*;
  logic              winc;
  logic [DATA_W-1:0] wdata;
  logic              wfull;
  initial begin winc = 0; wdata = '0; end

  clocking drv_cb @(posedge wclk);
    default input #1step output #1;
    output winc, wdata;
    input  wfull;
  endclocking

  clocking mon_cb @(posedge wclk);
    default input #1step;      // pre-edge values
    input winc, wdata, wfull;
  endclocking
endinterface

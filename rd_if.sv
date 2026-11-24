interface rd_if (input logic rclk, input logic rrst_n);
  import fifo_cfg_pkg::*;
  logic              rinc;
  logic [DATA_W-1:0] rdata;
  logic              rempty;
  initial rinc = 0;

  clocking drv_cb @(posedge rclk);
    default input #1step output #1;
    output rinc;
    input  rempty;
  endclocking

  clocking mon_cb @(posedge rclk);
    default input #1step;
    input rinc, rdata, rempty;
  endclocking
endinterface

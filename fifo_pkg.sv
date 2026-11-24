package fifo_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import fifo_cfg_pkg::*;
  `uvm_analysis_imp_decl(_wr)
  `uvm_analysis_imp_decl(_rd)
  `include "fifo_items_seqs.svh"
  `include "fifo_agents.svh"
  `include "fifo_scb.svh"
  `include "fifo_env_tests.svh"
endpackage

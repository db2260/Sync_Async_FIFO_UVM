// Scoreboard: reference queue + occupancy coverage
class fifo_scb extends uvm_scoreboard;
  `uvm_component_utils(fifo_scb)
  uvm_analysis_imp_wr #(wr_item, fifo_scb) wr_imp;
  uvm_analysis_imp_rd #(rd_item, fifo_scb) rd_imp;

  bit [DATA_W-1:0] q[$];
  int unsigned n_wr, n_rd, errors;
  int depth;

  covergroup cg_occ;
    cp_depth: coverpoint depth {
      bins empty = {0};
      bins low   = {[1:3]};
      bins mid   = {[4:DEPTH-4]};
      bins high  = {[DEPTH-3:DEPTH-1]};
      bins full  = {DEPTH};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wr_imp = new("wr_imp", this);
    rd_imp = new("rd_imp", this);
    cg_occ = new();
  endfunction

  function void write_wr(wr_item t);
    q.push_back(t.data);
    n_wr++;
    if (q.size() > DEPTH) begin
      errors++; `uvm_error("SCB", $sformatf("OVERFLOW: model depth %0d > %0d", q.size(), DEPTH))
    end
    depth = q.size(); cg_occ.sample();
  endfunction

  function void write_rd(rd_item t);
    bit [DATA_W-1:0] exp;
    if (q.size() == 0) begin
      errors++; `uvm_error("SCB", "UNDERFLOW: read accepted while model empty")
    end else begin
      exp = q.pop_front();
      n_rd++;
      if (t.data !== exp) begin
        errors++; `uvm_error("SCB", $sformatf("DATA MISMATCH got %0h exp %0h", t.data, exp))
      end
    end
    depth = q.size(); cg_occ.sample();
  endfunction

  function void check_phase(uvm_phase phase);
    if (q.size() != 0) begin
      errors++; `uvm_error("SCB", $sformatf("%0d entries never read", q.size()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("writes=%0d reads=%0d errors=%0d cov=%0.1f%%",
              n_wr, n_rd, errors, cg_occ.get_inst_coverage()), UVM_LOW)
    if (errors == 0) `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
    else             `uvm_info("SCB", "*** TEST FAILED ***", UVM_NONE)
  endfunction
endclass

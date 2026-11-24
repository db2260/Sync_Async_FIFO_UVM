// ---------------- item ----------------
class sync_item extends uvm_sequence_item;
  rand bit              wr_en, rd_en;
  rand bit [DATA_W-1:0] wdata;
  // monitor-side fields
  bit [DATA_W-1:0]      rdata;
  bit                   full, empty;
  bit [ADDR_W:0]        count;
  `uvm_object_utils(sync_item)
  function new(string name = "sync_item"); super.new(name); endfunction
endclass

// ---------------- sequence ----------------
class sync_seq extends uvm_sequence #(sync_item);
  `uvm_object_utils(sync_seq)
  int unsigned n = 200, wp = 50, rp = 50;     // write/read enable probability (%)
  function new(string name = "sync_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      req = sync_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with {
            wr_en dist {1 := wp, 0 := 100 - wp};
            rd_en dist {1 := rp, 0 := 100 - rp};
          }) `uvm_error("RAND", "randomize failed")
      finish_item(req);
    end
  endtask
endclass

// ---------------- driver ----------------
class sync_driver extends uvm_driver #(sync_item);
  `uvm_component_utils(sync_driver)
  virtual sync_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sync_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vif not set")
  endfunction
  task run_phase(uvm_phase phase);
    vif.drv_cb.wr_en <= 0; vif.drv_cb.rd_en <= 0; vif.drv_cb.wdata <= '0;
    wait (vif.rst_n === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      vif.drv_cb.wr_en <= req.wr_en;
      vif.drv_cb.rd_en <= req.rd_en;
      vif.drv_cb.wdata <= req.wdata;
      @(vif.drv_cb);
      seq_item_port.item_done();
    end
  endtask
endclass

// ---------------- monitor (every cycle) ----------------
class sync_monitor extends uvm_monitor;
  `uvm_component_utils(sync_monitor)
  virtual sync_if vif;
  uvm_analysis_port #(sync_item) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent); ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sync_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vif not set")
  endfunction
  task run_phase(uvm_phase phase);
    sync_item it;
    forever begin
      @(vif.mon_cb);
      if (vif.rst_n === 1'b1) begin
        it = sync_item::type_id::create("it");
        it.wr_en = vif.mon_cb.wr_en;  it.rd_en = vif.mon_cb.rd_en;
        it.wdata = vif.mon_cb.wdata;  it.rdata = vif.mon_cb.rdata;
        it.full  = vif.mon_cb.full;   it.empty = vif.mon_cb.empty;
        it.count = vif.mon_cb.count;
        ap.write(it);
      end
    end
  endtask
endclass

// ---------------- agent ----------------
class sync_agent extends uvm_agent;
  `uvm_component_utils(sync_agent)
  uvm_sequencer #(sync_item) sqr;
  sync_driver  drv;
  sync_monitor mon;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = uvm_sequencer #(sync_item)::type_id::create("sqr", this);
    drv = sync_driver ::type_id::create("drv", this);
    mon = sync_monitor::type_id::create("mon", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// ---------------- scoreboard ----------------
class sync_scb extends uvm_scoreboard;
  `uvm_component_utils(sync_scb)
  uvm_analysis_imp #(sync_item, sync_scb) imp;
  bit [DATA_W-1:0] q[$], exp;
  bit              rd_pend;                   // read data due next cycle
  int unsigned     n_wr, n_rd, errors;
  int              depth;
  bit              wr_when_full, rd_when_empty, rw_both;

  covergroup cg;
    cp_depth: coverpoint depth {
      bins empty = {0}; bins low = {[1:3]}; bins mid = {[4:DEPTH-4]};
      bins high = {[DEPTH-3:DEPTH-1]}; bins full = {DEPTH};
    }
    cp_wr_full:   coverpoint wr_when_full  {bins hit = {1};}
    cp_rd_empty:  coverpoint rd_when_empty {bins hit = {1};}
    cp_rw_both:   coverpoint rw_both       {bins hit = {1};}
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent); imp = new("imp", this); cg = new();
  endfunction

  function void err(string m); errors++; `uvm_error("SCB", m) endfunction

  function void write(sync_item t);
    // 1) read data registered on the previous edge
    if (rd_pend && t.rdata !== exp)
      err($sformatf("DATA MISMATCH got %0h exp %0h", t.rdata, exp));
    rd_pend = 0;
    // 2) flags/count reflect state before this edge
    if (t.full  !== (q.size() == DEPTH)) err($sformatf("FULL wrong (model depth %0d)",  q.size()));
    if (t.empty !== (q.size() == 0))     err($sformatf("EMPTY wrong (model depth %0d)", q.size()));
    if (t.count !== q.size())            err($sformatf("COUNT %0d != model %0d", t.count, q.size()));
    // 3) update model
    wr_when_full  = t.wr_en && t.full;
    rd_when_empty = t.rd_en && t.empty;
    rw_both       = t.wr_en && t.rd_en && !t.full && !t.empty;
    if (t.rd_en && !t.empty && q.size() > 0) begin
      exp = q.pop_front(); rd_pend = 1; n_rd++;
    end
    if (t.wr_en && !t.full) begin q.push_back(t.wdata); n_wr++; end
    depth = q.size(); cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("writes=%0d reads=%0d errors=%0d cov=%0.1f%%",
              n_wr, n_rd, errors, cg.get_inst_coverage()), UVM_LOW)
    if (errors == 0) `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
    else             `uvm_info("SCB", "*** TEST FAILED ***", UVM_NONE)
  endfunction
endclass

// ---------------- env + test ----------------
class sync_env extends uvm_env;
  `uvm_component_utils(sync_env)
  sync_agent agt;
  sync_scb   scb;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = sync_agent::type_id::create("agt", this);
    scb = sync_scb  ::type_id::create("scb", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    agt.mon.ap.connect(scb.imp);
  endfunction
endclass

class sync_test extends uvm_test;
  `uvm_component_utils(sync_test)
  sync_env env;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = sync_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);
    run_seq(500,  50,  50);    // balanced
    run_seq(200,  90,  10);    // fill  -> full
    run_seq(200,  10,  90);    // drain -> empty
    run_seq(300, 100, 100);    // back-to-back
    run_seq(60,    0, 100);    // final drain
    phase.drop_objection(this);
  endtask

  task run_seq(int unsigned n, int unsigned wp, int unsigned rp);
    sync_seq s = sync_seq::type_id::create("s");
    s.n = n; s.wp = wp; s.rp = rp;
    s.start(env.agt.sqr);
  endtask
endclass

// ================= ENV =================
class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)
  wr_agent wagt;
  rd_agent ragt;
  fifo_scb scb;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wagt = wr_agent::type_id::create("wagt", this);
    ragt = rd_agent::type_id::create("ragt", this);
    scb  = fifo_scb::type_id::create("scb",  this);
  endfunction
  function void connect_phase(uvm_phase phase);
    wagt.mon.ap.connect(scb.wr_imp);
    ragt.mon.ap.connect(scb.rd_imp);
  endfunction
endclass

// ================= TESTS =================
class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)
  fifo_env env;
  int unsigned n_txn = 500;
  int unsigned wmin = 0, wmax = 3, rmin = 0, rmax = 3;   // idle-cycle ranges
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env", this);
  endfunction
  virtual function void configure(); endfunction        // derived tests set knobs

  task run_phase(uvm_phase phase);
    wr_seq ws; rd_seq rs;
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 200ns);
    configure();
    ws = wr_seq::type_id::create("ws");  rs = rd_seq::type_id::create("rs");
    ws.n = n_txn; ws.imin = wmin; ws.imax = wmax;
    rs.n = n_txn; rs.imin = rmin; rs.imax = rmax;
    fork
      ws.start(env.wagt.sqr);
      rs.start(env.ragt.sqr);
    join
    phase.drop_objection(this);
  endtask
endclass

class balanced_test extends fifo_base_test;      // similar rates
  `uvm_component_utils(balanced_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void configure(); wmin=0; wmax=3; rmin=0; rmax=3; endfunction
endclass

class fill_test extends fifo_base_test;          // writer fast, reader slow -> FULL
  `uvm_component_utils(fill_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void configure(); n_txn=400; wmin=0; wmax=0; rmin=6; rmax=20; endfunction
endclass

class drain_test extends fifo_base_test;         // reader fast, writer slow -> EMPTY
  `uvm_component_utils(drain_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void configure(); n_txn=400; wmin=6; wmax=20; rmin=0; rmax=0; endfunction
endclass

class stress_test extends fifo_base_test;        // back-to-back both sides
  `uvm_component_utils(stress_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void configure(); n_txn=5000; wmin=0; wmax=0; rmin=0; rmax=0; endfunction
endclass

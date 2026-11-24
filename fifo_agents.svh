// ================= WRITE AGENT =================
class wr_driver extends uvm_driver #(wr_item);
  `uvm_component_utils(wr_driver)
  virtual wr_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual wr_if)::get(this, "", "wvif", vif))
      `uvm_fatal("NOVIF", "wvif not set")
  endfunction

  task run_phase(uvm_phase phase);
    vif.drv_cb.winc  <= 0;
    vif.drv_cb.wdata <= '0;
    wait (vif.wrst_n === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.idle > 0) begin
        vif.drv_cb.winc <= 0;
        repeat (req.idle) @(vif.drv_cb);
      end
      vif.drv_cb.winc  <= 1;
      vif.drv_cb.wdata <= req.data;
      do @(vif.drv_cb); while (vif.drv_cb.wfull);   // accepted when !wfull at the edge
      vif.drv_cb.winc <= 0;                         // overridden if next item has idle=0
      seq_item_port.item_done();
    end
  endtask
endclass

class wr_monitor extends uvm_monitor;
  `uvm_component_utils(wr_monitor)
  virtual wr_if vif;
  uvm_analysis_port #(wr_item) ap;
  int unsigned blocked_cnt;                         // write attempts while full
  function new(string name, uvm_component parent);
    super.new(name, parent); ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual wr_if)::get(this, "", "wvif", vif))
      `uvm_fatal("NOVIF", "wvif not set")
  endfunction

  task run_phase(uvm_phase phase);
    wr_item it;
    forever begin
      @(vif.mon_cb);
      if (vif.wrst_n === 1'b1 && vif.mon_cb.winc === 1'b1) begin
        if (vif.mon_cb.wfull === 1'b0) begin
          it = wr_item::type_id::create("it");
          it.data = vif.mon_cb.wdata;
          ap.write(it);
        end else blocked_cnt++;
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("WMON", $sformatf("writes blocked by FULL: %0d", blocked_cnt), UVM_LOW)
  endfunction
endclass

class wr_agent extends uvm_agent;
  `uvm_component_utils(wr_agent)
  uvm_sequencer #(wr_item) sqr;
  wr_driver  drv;
  wr_monitor mon;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = uvm_sequencer #(wr_item)::type_id::create("sqr", this);
    drv = wr_driver ::type_id::create("drv", this);
    mon = wr_monitor::type_id::create("mon", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// ================= READ AGENT =================
class rd_driver extends uvm_driver #(rd_item);
  `uvm_component_utils(rd_driver)
  virtual rd_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rd_if)::get(this, "", "rvif", vif))
      `uvm_fatal("NOVIF", "rvif not set")
  endfunction

  task run_phase(uvm_phase phase);
    vif.drv_cb.rinc <= 0;
    wait (vif.rrst_n === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.idle > 0) begin
        vif.drv_cb.rinc <= 0;
        repeat (req.idle) @(vif.drv_cb);
      end
      vif.drv_cb.rinc <= 1;
      do @(vif.drv_cb); while (vif.drv_cb.rempty);  // accepted when !rempty at the edge
      vif.drv_cb.rinc <= 0;
      seq_item_port.item_done();
    end
  endtask
endclass

class rd_monitor extends uvm_monitor;
  `uvm_component_utils(rd_monitor)
  virtual rd_if vif;
  uvm_analysis_port #(rd_item) ap;
  int unsigned blocked_cnt;                         // read attempts while empty
  function new(string name, uvm_component parent);
    super.new(name, parent); ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rd_if)::get(this, "", "rvif", vif))
      `uvm_fatal("NOVIF", "rvif not set")
  endfunction

  task run_phase(uvm_phase phase);
    rd_item it;
    forever begin
      @(vif.mon_cb);
      if (vif.rrst_n === 1'b1 && vif.mon_cb.rinc === 1'b1) begin
        if (vif.mon_cb.rempty === 1'b0) begin
          it = rd_item::type_id::create("it");
          it.data = vif.mon_cb.rdata;
          ap.write(it);
        end else blocked_cnt++;
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("RMON", $sformatf("reads blocked by EMPTY: %0d", blocked_cnt), UVM_LOW)
  endfunction
endclass

class rd_agent extends uvm_agent;
  `uvm_component_utils(rd_agent)
  uvm_sequencer #(rd_item) sqr;
  rd_driver  drv;
  rd_monitor mon;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = uvm_sequencer #(rd_item)::type_id::create("sqr", this);
    drv = rd_driver ::type_id::create("drv", this);
    mon = rd_monitor::type_id::create("mon", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// ---------------- items ----------------
class wr_item extends uvm_sequence_item;
  rand bit [DATA_W-1:0] data;
  rand int unsigned     idle;          // idle cycles before this write
  `uvm_object_utils(wr_item)
  function new(string name = "wr_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("data=%0h idle=%0d", data, idle);
  endfunction
endclass

class rd_item extends uvm_sequence_item;
  rand int unsigned     idle;          // idle cycles before this read
  bit [DATA_W-1:0]      data;          // filled by monitor
  `uvm_object_utils(rd_item)
  function new(string name = "rd_item"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("data=%0h idle=%0d", data, idle);
  endfunction
endclass

// ---------------- sequences ----------------
class wr_seq extends uvm_sequence #(wr_item);
  `uvm_object_utils(wr_seq)
  int unsigned n = 100, imin = 0, imax = 3;
  function new(string name = "wr_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      req = wr_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { idle inside {[imin:imax]}; })
        `uvm_error("RAND", "wr_item randomize failed")
      finish_item(req);
    end
  endtask
endclass

class rd_seq extends uvm_sequence #(rd_item);
  `uvm_object_utils(rd_seq)
  int unsigned n = 100, imin = 0, imax = 3;
  function new(string name = "rd_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      req = rd_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { idle inside {[imin:imax]}; })
        `uvm_error("RAND", "rd_item randomize failed")
      finish_item(req);
    end
  endtask
endclass

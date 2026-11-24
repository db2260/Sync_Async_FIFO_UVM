# UVM testbenches
uvm_async/  2 agents (write @wclk, read @rclk), scoreboard, coverage, SVA bind
uvm_sync/   1 agent, per-cycle scoreboard (data, full, empty, count), coverage

## Tests (async)  +UVM_TESTNAME=
balanced_test | fill_test | drain_test | stress_test

## Run (from uvm_async/ or uvm_sync/)
Xcelium : xrun -uvm -sv -f files.f +UVM_TESTNAME=fill_test
VCS     : vcs -sverilog -full64 -ntb_opts uvm-1.2 -f files.f && ./simv +UVM_TESTNAME=fill_test
Questa  : vlog -sv -f files.f && vsim -c tb_top +UVM_TESTNAME=fill_test -do "run -all"
xsim    : xvlog -sv -L uvm -f files.f && xelab -L uvm tb_top -s s && xsim s -R -testplusarg UVM_TESTNAME=fill_test
(uvm_sync runs sync_test by default)

Expected: "*** TEST PASSED ***"

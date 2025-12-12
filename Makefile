# DUT TOP AND TB TOP (the verilog module name)
TOP    = top
TB_TOP = tb_top

# SOURCE FILE DEFINITIONS (plus dependencies)
SOURCES    = src/top.sv src/top_01.sv
DEPS       =
LIBS       = src/lib/uart/uart_rx.sv src/lib/uart/uart_tx.sv
TB_SOURCES = tb/tb_top.sv tb/tb_01.sv
TB_DEPS    =

# VERILATOR DEFINITIONS
SIM_RESDIR = sim/verilated
SIM_TOOL   = verilator
SIM_FLAGS  = --binary -j 0 -Wno-lint --trace -Mdir $(SIM_RESDIR)

# FILE INPUTS/OUTPUTS
SIM_TOP         = tb_top
SIM_TOP_01      = top_01

SIM_TOP_FILE    = tb/tb_top.sv
SIM_TOP_FILE_01 = tb/tb_01.sv

SIM_DUT_FILE    = -f src/top.f
SIM_DUT_FILE_01 =

.PHONY: clean compile_sim run_sim generate_bitstream flash_bitstream

clean: 
	rm -f sim/verilated/*

compile:
	echo "no compile set up yet"


compile_sim_top: $(SOURCES) $(DEPS) $(TB_SOURCES) $(TB_DEPS)
	$(SIM_TOOL) $(SIM_FLAGS) -Isrc $(SIM_TOP_FILE) $(SIM_DUT_FILE)

compile_sim_01:
	echo "not yet implemented"

compile_sim_all:
	echo "not yet implemented"


$(SIM_RESDIR)/V$(SIM_TOP): compile_sim
	echo "compiling sim"

run_sim_top: $(SIM_RESDIR)/V$(SIM_TOP)
	$(SIM_RESDIR)/V$(SIM_TOP)

run_sim_01:
	echo "not yet implemented"

generate_bitstream: fpga/arty-a7-35t/compile.tcl
	vivado -mode batch -source fpga/arty-a7-35t/compile.tcl

flash_bitstream:
	echo "not yet implemented"
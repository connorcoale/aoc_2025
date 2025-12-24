# DUT TOP AND TB TOP (the verilog module name)
TOP    = top
TB_TOP = tb_top

# SOURCE FILE DEFINITIONS (plus dependencies)
SOURCES    = src/top.sv src/part_01.sv
DEPS       =
LIBS       = src/lib/uart/uart_rx.sv src/lib/uart/uart_tx.sv src/lib/mem/mem_arty_4kb_wrapper.sv src/lib/mem/mem_arty_205kb_wrapper.sv

# VERILATOR DEFINITIONS
SIM_RESDIR = sim/verilated
SIM_TOOL   = verilator
SIM_FLAGS  = --binary -j 0 -Wno-lint --trace -Mdir $(SIM_RESDIR)

# Simulation
TB_DEPS    =

SIM_SOURCES     = tb/tb_top.sv
SIM_TOP         = tb_top
SIM_TOP_FILE    = tb/tb_top.sv
SIM_DUT_FILE    = -f src/top.f

SIM_SOURCES_01  = tb/tb_01.sv
SIM_PART_01     = tb_01
SIM_TOP_FILE_01 = tb/tb_01.sv
SIM_DUT_FILE_01 = -f src/part_01.f

.PHONY: clean compile_sim run_sim generate_bitstream flash_bitstream

clean: 
	rm -f sim/verilated/*

compile:
	echo "no compile set up yet"


compile_sim_top: $(SOURCES) $(DEPS) $(SIM_SOURCES) $(TB_DEPS)
	$(SIM_TOOL) $(SIM_FLAGS) $(DEPS) $(SIM_SOURCES) $(TB_DEPS) -Isrc $(SIM_DUT_FILE)

compile_sim_01: $(SOURCES) $(DEPS) $(SIM_SOURCES_01) $(TB_DEPS)
	$(SIM_TOOL) $(SIM_FLAGS) $(DEPS) $(SIM_SOURCES_01) $(TB_DEPS) -Isrc $(SIM_DUT_FILE_01)

compile_sim_all:
	echo "not yet implemented"


$(SIM_RESDIR)/V$(SIM_TOP): compile_sim_top
	echo "compiling sim_top"

$(SIM_RESDIR)/V$(SIM_PART_01): compile_sim_01
	echo "compiling sim_01"

run_sim_top: $(SIM_RESDIR)/V$(SIM_TOP)
	$(SIM_RESDIR)/V$(SIM_TOP)

run_sim_01: $(SIM_RESDIR)/V$(SIM_PART_01)
	$(SIM_RESDIR)/V$(SIM_PART_01)

generate_bitstream: fpga/arty-a7-35t/compile.tcl
	vivado -mode batch -source fpga/arty-a7-35t/compile.tcl

flash_bitstream:
	echo "not yet implemented"
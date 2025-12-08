# DUT TOP AND TB TOP (the verilog module name)
TOP    = top
TB_TOP = tb_top

# SOURCE FILE DEFINITIONS (plus dependencies)
# SOURCES    = ../src/top/$(TOP).sv
SOURCES    = ../src/top/$(TOP).sv
DEPS       =
TB_SOURCES = $(TB_TOP).sv
TB_DEPS    =

# VERILATOR DEFINITIONS
SIM_RESDIR = out/verilated
SIM_TOOL   = verilator
SIM_FLAGS  = --binary -j 0 -Wno-lint --trace -Mdir $(SIM_RESDIR)

# FILE INPUTS/OUTPUTS
SIM_TOP      = $(TB_TOP)
SIM_TOP_FILE = $(TB_TOP).sv
SIM_DUT_FILE = -f ../src/top/top.f

.PHONY: clean compile_sim run_sim 

compile:
	echo "no compile set up yet"

clean: 
	rm -f out/verilated/*

compile_sim: $(SOURCES) $(DEPS) $(TB_SOURCES) $(TB_DEPS)
	$(SIM_TOOL) $(SIM_FLAGS) -I../src/top $(SIM_TOP_FILE) $(SIM_DUT_FILE)

$(SIM_RESDIR)/V$(SIM_TOP): compile_sim
	echo "compile_sim"

run_sim: $(SIM_RESDIR)/V$(SIM_TOP)
	$(SIM_RESDIR)/V$(SIM_TOP)
  


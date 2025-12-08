# PER-PROBLEM-DEFINITIONS
AOC_PROB      = 01
TOP_BASE_NAME = top
TB_BASE_NAME  = tb

# DUT TOP AND TB TOP (the verilog module name)
TOP    = $(TOP_BASE_NAME)_$(AOC_PROB)
TB_TOP = $(TB_BASE_NAME)_$(AOC_PROB)

# SOURCE FILE DEFINITIONS (plus dependencies)
SOURCES    = src/$(TOP).sv
DEPS       =
TB_SOURCES = test/$(TB_TOP).sv
TB_DEPS    =

# VERILATOR DEFINITIONS
SIM_RESDIR = out/verilated
SIM_TOOL   = verilator
SIM_FLAGS  = --binary -j 0 -Wno-lint --trace -Mdir $(SIM_RESDIR)

# FILE INPUTS/OUTPUTS
SIM_TOP      = $(TB_BASE_NAME)_$(AOC_PROB)
SIM_TOP_FILE = test/$(TB_TOP).sv
SIM_DUT_FILE = -f src/aoc_$(AOC_PROB).f

.PHONY: clean compile_sim run_sim

compile:
	echo "no compile set up yet"

clean: 
	rm -f out/verilated/*

compile_sim: $(SOURCES) $(DEPS) $(TB_SOURCES) $(TB_DEPS)
	$(SIM_TOOL) $(SIM_FLAGS) $(SIM_TOP_FILE) $(SIM_DUT_FILE)

$(SIM_RESDIR)/V$(SIM_TOP_FILE): compile_sim

run_sim: $(SIM_RESDIR)/V$(SIM_TOP_FILE)
	$(SIM_RESDIR)/V$(SIM_TOP)
  


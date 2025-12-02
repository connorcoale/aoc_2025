SOURCES = src/top_01.sv
DEPS    =

TB_SOURCES = tb/tb_01.sv
TB_DEPS    =

SIM_TOOL     = verilator
SIM_FLAGS    = --binary -j 0 -Wno-lint --trace -Mdir 
SIM_TOP      = tb_01 
SIM_TOP_FILE = test/tb_01.sv
SIM_DUT      = src/aoc_01.f
SIM_RESDIR   = out/verilated


TB_SOURCES = 
TB_DEPS =

compile:
	echo "no compile set up yet"

.PHONY: clean compile_sim run_sim

clean: 
	rm -f out/verilated/*

compile_sim: $(SOURCES) $(DEPS) $(TB_SOURCES) $(TB_DEPS)
	$(SIM_TOOL) $(SIM_FLAGS) $(SIM_RESDIR) $(SIM_TOP_FILE) -f $(SIM_DUT)

run_sim: $(SIM_RESDIR)/V*
	$(SIM_RESDIR)/V$(SIM_TOP)
  


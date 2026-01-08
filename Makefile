# ========================
# Project Configuration
# ========================

# Source files
SRC      = src/top.sv src/part_01.sv src/solution2char.sv
LIBS     = src/lib/uart/uart_rx.sv src/lib/uart/uart_tx.sv \
           src/lib/mem/mem_arty_full.sv \
           lib/bin2bcd/bin2bcd.sv

# Generated SV files
SCALA_SRC    = src/part_02.scala
CHISEL_GEN    = src/part_02.sv
HARDCAML_SRC = src/part_03/lib/solve_03.ml
HARDCAML_GEN = src/part_03.sv

# Testbenches
TBS      = tb_top tb_01 tb_02 tb_solution2char

# Simulation output directory
SIM_RESDIR = sim/verilated

# Verilator configuration
SIM_TOOL  = verilator
SIM_FLAGS = --binary -j 0 -Wno-lint --trace -Mdir $(SIM_RESDIR)

# FPGA bitstream
BITSTREAM = fpga/arty-a7-35t/top.bit
TCL_SCRIPT = fpga/arty-a7-35t/compile.tcl

# ========================
# PHONY targets
# ========================
.PHONY: all clean compile_sim run_sim run_sim_all generate_bitstream flash_bitstream

# ========================
# Default target
# ========================
all: compile_sim_all

# ========================
# Clean
# ========================
clean:
	rm -rf $(SIM_RESDIR)/*
	rm -f $(CHISEL_GEN)
	rm -f $(HARDCAML_GEN)
	rm -f $(BITSTREAM)
	rm -f sim/trace/*.vcd
	rm -f syn/*.rpt
	rm -f syn/*.pdf*
	rm -f syn/*.dot
	rm -f syn/*.log
	rm -rf src/part_03/_build/*

# ========================
# Scala -> SV generation
# ========================
GEN_CHISEL   = src/part_02.sv src/part_03.sv
gen_chisel: $(SCALA_SRC)
	scala-cli $(SCALA_SRC)

gen_hardcaml: $(HARDCAML_SRC)
	cd src/part_03 && dune build && ./_build/default/main.exe && cd ../..

$(CHISEL_GEN): gen_chisel
	echo "compiling chisel sources"
	
$(HARDCAML_GEN): gen_hardcaml
	echo "compiling hardcaml sources"

# ========================
# Simulation configuration
# ========================

SIM_TOOL  ?= verilator
SIM_FLAGS ?= --binary -j 0 -Wno-lint --trace
SIM_RESDIR ?= sim/verilated

# ========================
# Testbench lists
# ========================

# Numbered parts
PARTS := 01 02 # 03 04 05 06 07 08 09 10 11 12

# Named (non-numbered) testbenches
NAMED_TBS := tb_top tb_solution2char

# All testbenches (no path, no V prefix)
TBS := $(NAMED_TBS) $(addprefix tb_,$(PARTS))

# Corresponding verilated binaries
VERILATION_TARGETS := $(addprefix $(SIM_RESDIR)/V,$(TBS))

# ========================
# Create simulation directory
# ========================

$(SIM_RESDIR):
	mkdir -p $@

# ========================
# Verilator compilation rules
# ========================

# Pattern rule for numbered parts:
# tb/tb_<N>.sv -> sim/verilated/Vtb_<N>
$(SIM_RESDIR)/Vtb_%: tb/tb_%.sv | $(SIM_RESDIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
    --Mdir $(SIM_RESDIR) \
	  --prefix Vtb_$* \
	  tb/tb_n.sv \
	  -Isrc \
	  -f src/filelist/part_$*.f \
	  -DPART_NUM=$*

# Explicit rules for non-uniform testbenches
$(SIM_RESDIR)/Vtb_top: tb/tb_top.sv src/*.sv $(CHISEL_GEN) $(HARDCAML_GEN) | $(SIM_RESDIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
	  tb/tb_top.sv \
	  -Isrc \
	  -f src/filelist/top.f

$(SIM_RESDIR)/Vtb_solution2char: tb/tb_solution2char.sv src/lib/bin2bcd/bin2bcd.sv | $(SIM_RESDIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
	  tb/tb_solution2char.sv \
	  -Isrc \
	  -f src/filelist/solution2char.f

# ========================
# Compile all simulations
# ========================

.PHONY: compile_sim_all
compile_sim_all: $(VERILATION_TARGETS)
	@echo "All simulations compiled."

# ========================
# Run individual simulation
# ========================

.PHONY: run_sim_%
run_sim_%: $(SIM_RESDIR)/Vtb_%
	@echo "Running $<"
	$<

# ========================
# Run all simulations
# ========================

.PHONY: run_sim_all
run_sim_all: compile_sim_all
	@echo "Running all simulations..."
	@$(foreach tb,$(TBS), \
		echo ">>> Running $(SIM_RESDIR)/V$(tb)"; \
		$(SIM_RESDIR)/V$(tb) || exit 1; \
	)
	@echo "All simulations finished."


# # ========================
# # Create simulation directory
# # ========================
# $(SIM_RESDIR):
# 	mkdir -p $@

# # ========================
# # Verilator compilation (pattern rule)
# # ========================
# # Maps tb/tb_<name>.sv -> sim/verilated/V<name>

# VERILATION_TARGETS = $(SIM_RESDIR)/Vtb_top $(SIM_RESDIR)/Vtb_01 $(SIM_RESDIR)/Vtb_02 $(SIM_RESDIR)/Vtb_solution2char

# $(SIM_RESDIR)/Vtb_top: tb/tb_top.sv src/*.sv $(CHISEL_GEN) $(HARDCAML_GEN)
# 	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_top.sv -Isrc -f src/filelist/top.f

# # Rule for tb_01
# $(SIM_RESDIR)/Vtb_01: tb/tb_01.sv
# 	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_01.sv -Isrc -f src/filelist/part_01.f

# # Rule for tb_02
# $(SIM_RESDIR)/Vtb_02: tb/tb_02.sv $(CHISEL_GEN)
# 	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_02.sv -Isrc -f src/filelist/part_02.f

# # Rule for tb_solution2char
# $(SIM_RESDIR)/Vtb_solution2char: tb/tb_solution2char.sv src/lib/bin2bcd/bin2bcd.sv
# 	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_solution2char.sv -Isrc -f src/filelist/solution2char.f

# verilate_all: $(CHISEL_GEN) $(HARDCAML_GEN) $(VERILATION_TARGETS)

# # ========================
# # Compile all simulations
# # ========================
# compile_sim_all: verilate_all
# 	@echo "All simulations compiled."

# # ========================
# # Run individual simulation
# # ========================
# run_sim_%: $(SIM_RESDIR)/Vtb_%
# 	$<

# # ========================
# # Run all simulations
# # ========================
# run_sim_all: compile_sim_all
# 	@echo "Running all simulations..."
# 	$(foreach tb,$(TBS),$(SIM_RESDIR)/V$(tb);)
# 	@echo "All simulations finished."

# ========================
# Simple yosys synthesis
# ========================
.PHONY: syn
syn: $(CHISEL_GEN) $(HARDCAML_GEN)
	yosys -l syn/syn_top.log syn/syn_top.ys

# ========================
# Vivado bitstream generation
# ========================
$(BITSTREAM): $(TCL_SCRIPT)
	vivado -mode batch -source $<

generate_bitstream: $(BITSTREAM)

# ========================
# Flash FPGA
# ========================
flash_bitstream: $(BITSTREAM)
	echo "todo"
# ========================
# Project Configuration
# ========================

# Source files
SRC      = src/top.sv src/part_01.sv src/solution2char.sv
LIBS     = src/lib/uart/uart_rx.sv src/lib/uart/uart_tx.sv \
           src/lib/mem/mem_arty_4kb_wrapper.sv src/lib/mem/mem_arty_205kb_wrapper.sv \
           lib/bin2bcd/bin2bcd.sv

# Scala-generated SV files
SCALA_SRC = src/part_02.scala
GEN_SRC   = src/part_02.sv

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
	rm -f $(GEN_SRC)
	rm -f $(BITSTREAM)
	rm -f sim/trace/*.vcd
	rm -f syn/*.rpt
	rm -f syn/*.pdf*
	rm -f syn/*.dot
	rm -f syn/*.log

# ========================
# Scala -> SV generation
# ========================
$(GEN_SRC): $(SCALA_SRC)
	scala-cli $<

# ========================
# Create simulation directory
# ========================
$(SIM_RESDIR):
	mkdir -p $@

# ========================
# Verilator compilation (pattern rule)
# ========================
# Maps tb/tb_<name>.sv -> sim/verilated/V<name>

VERILATION_TARGETS = $(SIM_RESDIR)/Vtb_top $(SIM_RESDIR)/Vtb_01 $(SIM_RESDIR)/Vtb_02 $(SIM_RESDIR)/Vtb_solution2char

$(SIM_RESDIR)/Vtb_top: tb/tb_top.sv $(GEN_SRC)
	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_top.sv -Isrc -f src/filelist/top.f

# Rule for tb_01
$(SIM_RESDIR)/Vtb_01: tb/tb_01.sv
	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_01.sv -Isrc -f src/filelist/part_01.f

# Rule for tb_02
$(SIM_RESDIR)/Vtb_02: tb/tb_02.sv $(GEN_SRC)
	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_02.sv -Isrc -f src/filelist/part_02.f

# Rule for tb_solution2char
$(SIM_RESDIR)/Vtb_solution2char: tb/tb_solution2char.sv
	$(SIM_TOOL) $(SIM_FLAGS) tb/tb_solution2char.sv -Isrc -f src/filelist/solution2char.f

verilate_all: $(GEN_SRC) $(VERILATION_TARGETS)

#$(SIM_RESDIR)/V%: tb/%.sv $(SRC) $(LIBS) $(SIM_RESDIR) $(GEN_SRC)
#$(SIM_TOOL) $(SIM_FLAGS) tb/$*.sv -Isrc -f top.f

# ========================
# Compile all simulations
# ========================
compile_sim_all: verilate_all
	@echo "All simulations compiled."

# ========================
# Run individual simulation
# ========================
run_sim_%: $(SIM_RESDIR)/Vtb_%
	$<

# ========================
# Run all simulations
# ========================
run_sim_all: compile_sim_all
	@echo "Running all simulations..."
	$(foreach tb,$(TBS),$(SIM_RESDIR)/V$(tb);)
	@echo "All simulations finished."

# ========================
# Simple yosys synthesis
# ========================
.PHONY: syn
syn: $(GEN_SRC)
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
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
CHISEL_GEN   = src/part_02.sv
HARDCAML_SRC = src/part_03/lib/solve_03.ml src/part_03/lib/find_max_bounded.ml src/part_03/main.ml
HARDCAML_GEN = src/part_03.sv
GEN          = $(CHISEL_GEN) $(HARDCAML_GEN)

# Testbenches
TBS      = tb_top tb_01 tb_02 tb_solution2char

# Simulation output directory
SIM_BUILD_DIR = sim/verilated

# Reference results directory
SIM_REF_DIR = sim/results

# FPGA bitstream
BITSTREAM = fpga/arty-a7-35t/top.bit
TCL_SCRIPT = fpga/arty-a7-35t/compile.tcl

# ========================
# PHONY targets
# ========================
.PHONY: all help clean gen_chisel gen_hardcaml gen_all compile_sim_all compile_sim_run run_sim_% run_sim_all run_sim_top syn generate_bitstream flash_bitstream FORCE

# ========================
# Help target
# ========================
help:
	@echo "Available targets:"
	@echo "  make check_deps       - Verify all required tools are installed"
	@echo "  make gen_chisel       - Generate Chisel RTL (part_02)"
	@echo "  make gen_hardcaml     - Generate Hardcaml RTL (part_03)"
	@echo "  make gen_all          - Generate all RTL from HDL sources"
	@echo "  make compile_sim_all  - Compile all Verilator simulations"
	@echo "  make run_sim_all      - Run all named TBs and numbered part simulations"
	@echo "  make run_sim_<part>   - Run specific part (01, 02, 03, etc)"
	@echo "  make syn              - Run Yosys synthesis"
	@echo "  make run_sim_top      - Run top-level simulation only"
	@echo "  make clean            - Clean build artifacts"

# ========================
# Dependency check
# ========================
C_GREEN  := \033[0;32m
C_YELLOW := \033[0;33m
C_RED    := \033[0;31m
C_RESET  := \033[0m

.PHONY: check_deps
check_deps:
	@echo "=== aoc_2025 — Dependency Check ==="
	@echo ""
	@echo "--- Required Tools ---"
	@ok=0; fail=0; \
	for tool in verilator scala-cli dune opam python3; do \
		if command -v $${tool} >/dev/null 2>&1; then \
			printf "  $(C_GREEN)[PASS]$(C_RESET) $${tool}\n"; ok=$$((ok+1)); \
		else \
			printf "  $(C_RED)[FAIL]$(C_RESET) $${tool}\n"; fail=$$((fail+1)); \
		fi; \
	done; \
	if command -v c++ >/dev/null 2>&1; then \
		printf "  $(C_GREEN)[PASS]$(C_RESET) c++ (C++ compiler)\n"; ok=$$((ok+1)); \
	else \
		printf "  $(C_RED)[FAIL]$(C_RESET) c++ (C++ compiler, needed by Verilator)\n"; fail=$$((fail+1)); \
	fi; \
	echo ""; \
	echo "--- OCaml / OPAM Packages (for Hardcaml) ---"; \
	for pkg in hardcaml ppx_hardcaml ppx_enumerate ppx_compare; do \
		if opam list --installed $${pkg} >/dev/null 2>&1; then \
			printf "  $(C_GREEN)[PASS]$(C_RESET) $${pkg}\n"; ok=$$((ok+1)); \
		else \
			printf "  $(C_RED)[FAIL]$(C_RESET) $${pkg}\n"; fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; \
	echo "--- Optional Tools ---"; \
	if command -v yosys >/dev/null 2>&1; then \
		printf "  $(C_GREEN)[PASS]$(C_RESET) yosys\n"; ok=$$((ok+1)); \
	else \
		printf "  $(C_YELLOW)[SKIP]$(C_RESET) yosys (not found - syn only)\n"; \
	fi; \
	if command -v vivado >/dev/null 2>&1; then \
		printf "  $(C_GREEN)[PASS]$(C_RESET) vivado\n"; ok=$$((ok+1)); \
	else \
		printf "  $(C_YELLOW)[SKIP]$(C_RESET) vivado (not found — bitstream/fpga flashing only)\n"; \
	fi; \
	echo ""; \
	printf "$(C_GREEN)Result: $${ok}/$$((ok+fail)) required checks passed$(C_RESET)\n"

# ========================
# Default target
# ========================
all: compile_sim_all

# ========================
# Clean
# ========================
clean:
	rm -rf $(SIM_BUILD_DIR)/*
	rm -f $(CHISEL_GEN)
	rm -f $(HARDCAML_GEN)
	rm -f $(BITSTREAM)
	rm -f sim/trace/*.vcd
	rm -f syn/*.rpt
	rm -f syn/*.pdf*
	rm -f syn/*.dot
	rm -f syn/*.log
	rm -rf src/part_03/_build/*
	rm -rf $(SIM_REF_DIR)

# ========================
# Scala -> SV generation
# ========================

$(CHISEL_GEN): $(SCALA_SRC)
	scala-cli $(SCALA_SRC)

gen_chisel: $(CHISEL_GEN)

$(HARDCAML_GEN): $(HARDCAML_SRC)
	cd src/part_03 && dune build && ./_build/default/main.exe && cd ../..

gen_hardcaml: $(HARDCAML_GEN)

gen_all: $(GEN)

# ========================
# Simulation configuration
# ========================

SIM_TOOL  ?= verilator
VERBOSE   ?=
TRACE     ?=
QUIET = $(if $(VERBOSE),,--quiet-build --quiet-stats)
SIM_FLAGS ?= --binary -j 0 -Wno-lint --trace $(QUIET)
SIM_BUILD_DIR ?= sim/verilated

# ========================
# Testbench lists
# ========================

# Numbered parts
PARTS := 01 02 03 # 04 05 06 07 08 09 10 11 12

# Named (non-numbered) testbenches
NAMED_TBS := tb_top tb_solution2char

# Named testbenches included in run_sim_all (excludes tb_top)
NAMED_TBS_RUN := tb_solution2char

# All testbenches (no path, no V prefix)
TBS := $(NAMED_TBS) $(addprefix tb_,$(PARTS))
TBS_RUN := $(NAMED_TBS_RUN) $(addprefix tb_,$(PARTS))

# Corresponding verilated binaries
VERILATION_TARGETS := $(addprefix $(SIM_BUILD_DIR)/V,$(TBS))
VERILATION_TARGETS_RUN := $(addprefix $(SIM_BUILD_DIR)/V,$(TBS_RUN))

# ========================
# Create simulation directory
# ========================

$(SIM_BUILD_DIR):
	mkdir -p $@

# ========================
# Verilator compilation rules
# ========================
EXTRA_VARGS_02 := -DPART_OUTPUT_BCD
EXTRA_VARGS_03 := --gate-stmts 5
EXTRA_VARGS_TOP ?=

ifneq ($(TRACE),)
EXTRA_VARGS_TOP += -DTRACE
endif

ifneq ($(BACKDOOR),)
EXTRA_VARGS_TOP += -DBACKDOOR_LOAD -DBACKDOOR_READ
endif

# Pattern rule for numbered parts:
# tb/tb_<N>.sv -> sim/verilated/Vtb_<N>
# Each part depends only on its own generated HDL sources (if any)
$(SIM_BUILD_DIR)/Vtb_01: | $(SIM_BUILD_DIR)
$(SIM_BUILD_DIR)/Vtb_02: $(CHISEL_GEN) | $(SIM_BUILD_DIR)
$(SIM_BUILD_DIR)/Vtb_03: $(HARDCAML_GEN) | $(SIM_BUILD_DIR)
$(SIM_BUILD_DIR)/Vtb_%: tb/tb_n.sv | $(SIM_BUILD_DIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
    --Mdir $(SIM_BUILD_DIR) \
	  --prefix Vtb_$* \
	  tb/tb_n.sv \
	  -Isrc \
	  -f src/filelist/part_$*.f \
		$(EXTRA_VARGS_$*) \
	  -DPART_NUM=$*

# Track flag changes for Vtb_top rebuild (e.g. TRACE=1)
FORCE:

$(SIM_BUILD_DIR)/.topflags: FORCE
	@echo '$(EXTRA_VARGS_TOP)' > $@.tmp
	@cmp -s $@.tmp $@ 2>/dev/null || cp $@.tmp $@
	@rm -f $@.tmp

# Explicit rules for non-uniform testbenches
$(SIM_BUILD_DIR)/Vtb_top: tb/tb_top.sv src/*.sv $(CHISEL_GEN) $(HARDCAML_GEN) $(SIM_BUILD_DIR)/.topflags | $(SIM_BUILD_DIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
	  --Mdir $(SIM_BUILD_DIR) \
	  --prefix Vtb_top \
	  --top-module tb_top \
	  tb/tb_top.sv \
	  -Isrc \
	  -f src/filelist/top.f \
			$(EXTRA_VARGS_TOP)

$(SIM_BUILD_DIR)/Vtb_solution2char: tb/tb_solution2char.sv src/lib/bin2bcd/bin2bcd.sv | $(SIM_BUILD_DIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
	  --Mdir $(SIM_BUILD_DIR) \
	  --prefix Vtb_solution2char \
	  tb/tb_solution2char.sv \
	  -Isrc \
	  -f src/filelist/solution2char.f

# ========================
# Compile all simulations
# ========================

.PHONY: compile_sim_all compile_sim_run
compile_sim_all: $(VERILATION_TARGETS)
	@echo "All simulations compiled."

compile_sim_run: $(VERILATION_TARGETS_RUN)
	@echo "Run-sim simulations compiled."

# ========================
# Run individual simulation
# ========================

.PHONY: run_sim_%
run_sim_%: $(SIM_BUILD_DIR)/Vtb_%
	@if [ -f sim/stimulus/$*/ref_$*.py ]; then \
	  mkdir -p $(SIM_REF_DIR); \
	  python3 sim/stimulus/$*/ref_$*.py sim/stimulus/$*/input_$*.txt $(SIM_REF_DIR); \
	fi
	@echo "Running $<"
	$<

# ========================
# Run all simulations
# ========================

.PHONY: run_sim_top run_sim_all
run_sim_top: $(SIM_BUILD_DIR)/Vtb_top
	@echo "============================================"
	@echo "  Top-Level Simulation"
	@echo "============================================"
	@mkdir -p $(SIM_REF_DIR); \
	for p in $(PARTS); do \
	  if [ -f sim/stimulus/$$p/ref_$$p.py ]; then \
	    python3 sim/stimulus/$$p/ref_$$p.py sim/stimulus/$$p/input_$$p.txt $(SIM_REF_DIR); \
	  fi; \
	done
	$(SIM_BUILD_DIR)/Vtb_top

.PHONY: run_sim_all
run_sim_all: compile_sim_run
	@echo "============================================"
	@echo "  All Simulations"
	@echo "============================================"
	@pass=0; fail=0; warn=0; \
	mkdir -p $(SIM_REF_DIR); \
	for p in $(PARTS); do \
	  if [ -f sim/stimulus/$$p/ref_$$p.py ]; then \
	    python3 sim/stimulus/$$p/ref_$$p.py sim/stimulus/$$p/input_$$p.txt $(SIM_REF_DIR); \
	  fi; \
	done; \
	for tb in $(NAMED_TBS_RUN) $(addprefix tb_,$(PARTS)); do \
	  echo ""; \
	  echo ">>> $$tb"; \
	  $(SIM_BUILD_DIR)/V$$tb > $(SIM_BUILD_DIR)/.out_$$tb 2>&1; \
	  cat $(SIM_BUILD_DIR)/.out_$$tb; \
	  p=$$(grep -oE 'PASS:' $(SIM_BUILD_DIR)/.out_$$tb 2>/dev/null | wc -l); \
	  f=$$(grep -oE 'FAIL:' $(SIM_BUILD_DIR)/.out_$$tb 2>/dev/null | wc -l); \
	  w=$$(grep -oE 'WARN:' $(SIM_BUILD_DIR)/.out_$$tb 2>/dev/null | wc -l); \
	  pass=$$((pass + p)); \
	  fail=$$((fail + f)); \
	  warn=$$((warn + w)); \
	  rm -f $(SIM_BUILD_DIR)/.out_$$tb; \
	done; \
	echo ""; \
	echo "============================================"; \
	printf "  $(C_GREEN)%d passed$(C_RESET), $(C_RED)%d failed$(C_RESET), $(C_YELLOW)%d warnings$(C_RESET)\n" $$pass $$fail $$warn; \
	echo "============================================"

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
.PHONY: flash_bitstream
flash_bitstream:
	@echo "Vivado bitstream generation not available on macOS"
	@echo "Build bitstream on a Linux machine with Vivado installed"
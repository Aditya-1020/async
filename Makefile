SBY_FILE ?= async_fifo_2ff.sby
SIM       ?= verilator
TOP_LEVEL_LANG ?= verilog
VERILOG_SOURCES ?= src/fifo_mem.v src/fifo_sram_16x64_pdp.v
TOPLEVEL  ?= fifo_mem
COCOTB_TEST_MODULES ?= tb.fifo_mem
ACTIVATE_VENV := . .venv/bin/activate
NIX_SHELL  = nix-shell --pure ~/openlane2/shell.nix
EXTRA_ARGS += --no-timing

.PHONY: all clean formal lint sim venv

all: venv sim

venv:
	python3 -m venv .venv
	$(ACTIVATE_VENV) && pip install --upgrade pip && pip install cocotb

formal:
	sby -f formal/$(SBY_FILE)

lint:
	verilator --lint-only -Wall src/*.v

nix-shell:
	$(NIX_SHELL)

sim:
	$(ACTIVATE_VENV) && \
	SIM=$(SIM) \
	TOP_LEVEL_LANG=$(TOP_LEVEL_LANG) \
	VERILOG_SOURCES="$(VERILOG_SOURCES)" \
	TOPLEVEL=$(TOPLEVEL) \
	COCOTB_TEST_MODULES=$(COCOTB_TEST_MODULES) \
	EXTRA_ARGS="$(EXTRA_ARGS)" \
	$(MAKE) -f $$(cocotb-config --makefiles)/Makefile.sim

clean:
	rm -rf __pycache__ results.xml *.vcd
	rm -rf tb/__pycache__
	rm -rf sim_build
	rm -rf formal/async_fifo_2ff formal/rst_sync formal/sync_fifo
	rm -rf *.jou *.log
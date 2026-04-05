SBY_FILE ?= async_fifo.sby
SIM ?= verilator
TOP_LEVEL_LANG ?= verilog
VERILOG_SOURCES ?= src/async_fifo.v src/fifo_mem.v src/ptr_inc.v src/rst_sync.v src/fifo_sram_16x64_pdp.v src/sync_2ff.v
TOPLEVEL  ?= async_fifo
COCOTB_TEST_MODULES ?= tb.async_fifo
ACTIVATE_VENV := . .venv/bin/activate
NIX_SHELL  = nix-shell --pure ~/openlane2/shell.nix
TRACE_FORMAT ?= fst

ifeq ($(TRACE_FORMAT), fst)
	EXTRA_ARGS := --no-timing --trace --trace-fst --trace-structs
else
	EXTRA_ARGS := --no-timing --trace
endif

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
	rm -rf __pycache__ results.xml
	rm -rf tb/__pycache__
	rm -rf sim_build
	rm -rf formal/async_fifo formal/rst_sync formal/sync_fifo formal/fifo_mem
	rm -rf *.jou *.log *.vcd *.fst
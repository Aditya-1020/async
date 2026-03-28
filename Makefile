SBY_FILE ?= async_fifo_2ff.sby
SIM ?= verilator
TOP_LEVEL_LANG ?= verilog
SIM_ARGS   ?= --trace
VERILOG_SOURCES ?= src/fifo_mem.v src/sync_fifo/sync_fifo.v
TOPLEVEL   ?= sync_fifo
COCOTB_TEST_MODULES ?= tb.tb_sync_fifo

ACTIVATE_VENV := . .venv/bin/activate

.PHONY: all clean formal lint sim venv

all: venv sim

venv:
	python3 -m venv .venv
	$(ACTIVATE_VENV) && pip install --upgrade pip && pip install cocotb

formal:
	sby -f formal/$(SBY_FILE)

lint:
	verilator --lint-only -Wall src/*.v

sim:
	$(ACTIVATE_VENV) && \
	SIM=$(SIM) \
	TOP_LEVEL_LANG=$(TOP_LEVEL_LANG) \
	VERILOG_SOURCES="$(VERILOG_SOURCES)" \
	TOPLEVEL=$(TOPLEVEL) \
	COCOTB_TEST_MODULES=$(COCOTB_TEST_MODULES) \
	$(MAKE) -f $$(cocotb-config --makefiles)/Makefile.sim

clean:
	rm -rf sim_build __pycache__ results.xml *.vcd
	rm -rf tb/__pycache__
	rm -rf formal/async_fifo_2ff formal/rst_sync
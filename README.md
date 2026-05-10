# Async FIFO

A dual-clock asynchronous FIFO in Verilog with formal verification and cocotb simulation.

## Architecture

- 16-bit wide, 64-entry depth (6-bit address)
- Gray-coded read/write pointers for CDC safety
- 2-flop synchronizers for pointer crossing
- Reset synchronizers for each clock domain
- OpenRAM pseudo-dual-port SRAM macro (16×64, SKY130) for storage

## Verification

**Formal** (SymbiYosys + smtbmc/Boolector)
- `async_fifo`: BMC, depth 128, multiclock, no-overflow, no-underflow, full/empty mutual exclusion
- `rst_sync`, `fifo_mem`, `sync_fifo`: k-induction (`mode prove`)
- OpenRAM model replaced with a combinational stub for formal

**Simulation** (cocotb + Verilator)
- 13 testcases across `async_fifo` and `fifo_mem`
- Covers: reset state, full/empty conditions, pointer wraparound, concurrent read/write, asymmetric clock ratios (up to 4:1)

## Usage

```bash
# Simulation
make sim

# Formal verification
make formal SBY_FILE=async_fifo.sby

# Lint
make lint
```
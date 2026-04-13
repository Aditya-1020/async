import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
import random

DATA_WIDTH = 16
ADDR_WIDTH = 6
FIFO_DEPTH = 2 ** ADDR_WIDTH  # 64 entries
DATA_MASK  = (1 << DATA_WIDTH) - 1
# from fifo_sram_16x64_pdp.v
# DELAY=3ns, T_HOLD=1ns
SRAM_READ_DELAY_NS = 4  # 3ns DELAY + 1ns margin

async def reset_dut(dut):
    dut.wr_rst_n.value = 0
    dut.rd_rst_n.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    for _ in range(3):
        await RisingEdge(dut.wr_clk)
    dut.wr_rst_n.value = 1
    dut.rd_rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.wr_clk)

async def write_word(dut, data):
    dut.wr_en.value = 1
    dut.wr_data.value = data
    await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0
    await RisingEdge(dut.wr_clk)

async def read_word(dut):
    dut.rd_en.value = 1
    await RisingEdge(dut.rd_clk)
    await FallingEdge(dut.rd_clk)
    await Timer(1, unit="ns")
    dut.rd_en.value = 0
    return dut.rd_data.value.to_unsigned()

async def start_clk(dut, wr_clk_period, rd_clk_period, wr_unit, rd_unit):
    cocotb.start_soon(Clock(dut.wr_clk, wr_clk_period, unit=wr_unit).start())
    cocotb.start_soon(Clock(dut.rd_clk, rd_clk_period, unit=rd_unit).start())

@cocotb.test()
async def simple_write_read_test(dut):
    dut._log.info("Waveform will be written to dump.vcd")
    await start_clk(dut, 10, 15, "ns", "ns")
    await reset_dut(dut)

    data = random.randint(0, DATA_MASK)
    await write_word(dut, data)
    
    for _ in range(4):
        await RisingEdge(dut.rd_clk)
    
    read_data = await read_word(dut)
    assert read_data == data, f"Read {hex(read_data)} != written {hex(data)}"


@cocotb.test()
async def test_reset_state(dut):
    """After reset: empty=1, full=0, overflow=0, underflow=0"""
    dut._log.info("Reset state")
    await start_clk(dut, 10, 15, "ns", "ns")
    await reset_dut(dut)
    assert dut.empty.value == 1, "FIFO should be empty after reset"
    assert dut.full.value == 0, "FIFO should not be full after reset"
    assert dut.overflow.value == 0, "FIFO should not overflow asserted after reset"
    assert dut.underflow.value == 0, "FIFO should not underflow asserted after reset"
    dut._log.info("Reset state verified")

@cocotb.test()
async def test_full_condition(dut):
    """Write 64 words, assert full goes high, assert overflow on 65th write"""
    dut._log.info("Full condition")
    await start_clk(dut, 10, 15, "ns", "ns")
    await reset_dut(dut)
    for i in range(FIFO_DEPTH):
        await write_word(dut, i)
    assert dut.full.value == 1, "FIFO should be full after full write"
    assert (dut.overflow.value and dut.underflow.value) == 0, "overflow and underflow should not be asserted when full"
    dut._log.info("Full condition verified")

@cocotb.test()
async def test_empty_condition(dut):
    """Read from empty FIFO, assert underflow, assert rd_data not consumed"""
    dut._log.info("Empty Condition")
    await start_clk(dut, 10, 15, "ns", "ns")
    await reset_dut(dut)
    assert dut.empty.value == 1, "Fifo should be empty after full reset"
    assert dut.wr_ptr_g_sync.value == 0, "write poiter should be 0 aftere reset"
    assert dut.rd_ptr_g_sync.value == 0, "read pointer should be 0"
    read_data = await read_word(dut)
    assert dut.underflow.value == 1, "underflow should be asserted when reading"
    assert read_data == 0, f"read data should be 0 when underflow, got {hex(read_data)}"
    dut._log.info("Empty condition verified")

# @cocotb.test()
# async def test_fill_and_drain(dut):
#     """Write 64 words sequentially, drain all 64, verify each word in order"""
#     pass
 
# @cocotb.test()
# async def test_pointer_wraparound(dut):
#     """Fill, drain, fill again — forces wr_ptr and rd_ptr to wrap past 0"""
#     pass
 
# @cocotb.test()
# async def test_concurrent_rw(dut):
#     """Pre-fill half, then write and read simultaneously, verify no data loss"""
#     pass
 
# @cocotb.test()
# async def test_asymmetric_reset(dut):
#     """Assert only wr_rst_n, verify write side resets but read side holds state"""
#     """Assert only rd_rst_n, verify read side resets but write side holds state"""
#     pass
 
# @cocotb.test()
# async def test_clock_ratio_fast_write(dut):
#     """wr_clk 4x faster than rd_clk — stress synchronizer latency"""
#     pass
 
# @cocotb.test()
# async def test_clock_ratio_fast_read(dut):
#     """rd_clk 4x faster than wr_clk — verify empty propagates correctly"""
#     pass
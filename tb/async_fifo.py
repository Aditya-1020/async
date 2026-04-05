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

@cocotb.test()
async def simple_write_read_test(dut):
    dut._log.info("Waveform will be written to dump.vcd")
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 15, unit="ns").start())
    await reset_dut(dut)

    data = random.randint(0, DATA_MASK)
    await write_word(dut, data)
    
    for _ in range(4):
        await RisingEdge(dut.rd_clk)
    
    read_data = await read_word(dut)
    assert read_data == data, f"Read {hex(read_data)} != written {hex(data)}"

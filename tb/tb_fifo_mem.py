import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

DATA_WIDTH = 8
ADDR_WIDTH = 4
FIFO_DEPTH = 2 ** ADDR_WIDTH

"""
fifo_mem ports:
    input  wr_clk
    input  wr_en
    input  [ADDR_WIDTH-1:0] wr_addr
    input  [DATA_WIDTH-1:0] wr_data
    input  [ADDR_WIDTH-1:0] rd_addr
    output [DATA_WIDTH-1:0] rd_data
"""

async def reset_dut(dut):
    dut.wr_en.value = 0
    dut.wr_addr.value = 0
    dut.wr_data.value = 0
    dut.rd_addr.value = 0
    await RisingEdge(dut.wr_clk)
    await RisingEdge(dut.wr_clk)


async def write_word(dut, addr, data):
    dut.wr_en.value = 1
    dut.wr_addr.value = addr
    dut.wr_data.value = data
    await RisingEdge(dut.wr_clk)
    dut.wr_en.value   = 0


async def read_word(dut, addr):
    dut.rd_addr.value = addr
    await Timer(1, unit="ns")
    return dut.rd_data.value.integer


@cocotb.test()
async def test_write_read_sequential(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    await reset_dut(dut)

    log.info("test_write_read_sequential: start")
    for addr in range(FIFO_DEPTH):
        data = random.randint(0, 2**DATA_WIDTH - 1)
        await write_word(dut, addr, data)
        readback = await read_word(dut, addr)
        assert readback == data, (f"FAIL addr={addr}: wrote {data:#04x}, read {readback:#04x}")
        log.info(f"  addr={addr} data={data:#04x} OK")

    log.info("test_write_read_sequential: PASS")


@cocotb.test()
async def test_fill_and_drain(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    await reset_dut(dut)

    log.info("test_fill_and_drain: writing all entries")
    written = [0] * FIFO_DEPTH
    for addr in range(FIFO_DEPTH):
        data = random.randint(0, 2**DATA_WIDTH - 1)
        written[addr] = data
        await write_word(dut, addr, data)

    log.info("test_fill_and_drain: reading back all entries")
    for addr in range(FIFO_DEPTH):
        readback = await read_word(dut, addr)
        assert readback == written[addr], (f"FAIL addr={addr}: expected {written[addr]:#04x}, got {readback:#04x}")

    log.info("test_fill_and_drain: PASS")
    assert dut.empty.value, "FAIL: fifo not empty after draining"
    log.info("test_fill_and_drain: PASS")


# overwrite same address
@cocotb.test()
async def test_overwrite(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    await reset_dut(dut)

    first  = random.randint(0, 2**DATA_WIDTH - 1)
    second = (first + 1) % (2**DATA_WIDTH)

    await write_word(dut, 0, first)
    await write_word(dut, 0, second)

    readback = await read_word(dut, 0)
    assert readback == second, (f"FAIL overwrite: expected {second:#04x}, got {readback:#04x}")
    log.info(f"test_overwrite: PASS (first={first:#04x} second={second:#04x})")


@cocotb.test()
async def test_write_enable_gate(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    await reset_dut(dut)

    # Write a known value
    await write_word(dut, 0, 0xAB)

    # Attempt a write with wr_en=0 — should be ignored
    dut.wr_en.value   = 0
    dut.wr_addr.value = 0
    dut.wr_data.value = 0xFF
    await RisingEdge(dut.wr_clk)

    readback = await read_word(dut, 0)
    assert readback == 0xAB, (f"FAIL wr_en gate: memory changed to {readback:#04x} without wr_en")
    log.info("test_write_enable_gate: PASS")


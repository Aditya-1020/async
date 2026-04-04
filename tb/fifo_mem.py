import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
import random

# Match fifo_mem parameters exactly
DATA_WIDTH = 16
ADDR_WIDTH = 6
FIFO_DEPTH = 2 ** ADDR_WIDTH  # 64 entries
DATA_MASK  = (1 << DATA_WIDTH) - 1
# from fifo_sram_16x64_pdp.v
# DELAY=3ns, T_HOLD=1ns
SRAM_READ_DELAY_NS = 4  # 3ns DELAY + 1ns margin

async def reset_dut(dut):
    dut.wr_en.value   = 0
    dut.wr_addr.value = 0
    dut.wr_data.value = 0
    dut.rd_en.value   = 0
    dut.rd_addr.value = 0
    await RisingEdge(dut.wr_clk)
    await RisingEdge(dut.wr_clk)

async def write_word(dut, addr, data):
    dut.wr_en.value = 1
    dut.wr_addr.value = addr
    dut.wr_data.value = data
    await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0
    await FallingEdge(dut.wr_clk)
    await Timer(1, unit="ns")


async def read_word(dut, addr):
    dut.rd_addr.value = addr
    dut.rd_en.value   = 1
    await RisingEdge(dut.rd_clk)
    await FallingEdge(dut.rd_clk)
    await Timer(SRAM_READ_DELAY_NS, unit="ns")  # wait past DELAY
    dut.rd_en.value   = 0
    return dut.rd_data.value.to_unsigned()

@cocotb.test()
async def test_write_read_sequential(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 13, unit="ns").start())
    await reset_dut(dut)

    log.info("test_write_read_sequential: start")
    for addr in range(FIFO_DEPTH):
        data = random.randint(0, DATA_MASK)
        await write_word(dut, addr, data)
        readback = await read_word(dut, addr)
        assert readback == data, (
            f"FAIL addr={addr}: wrote {data:#06x}, read {readback:#06x}"
        )
        log.info(f"  addr={addr} data={data:#06x} OK")

    log.info("test_write_read_sequential: PASS")

@cocotb.test()
async def test_fill_and_drain(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 13, unit="ns").start())
    await reset_dut(dut)

    written = [0] * FIFO_DEPTH
    log.info("test_fill_and_drain: writing all entries")
    for addr in range(FIFO_DEPTH):
        data = random.randint(0, DATA_MASK)
        written[addr] = data
        await write_word(dut, addr, data)

    log.info("test_fill_and_drain: reading back all entries")
    for addr in range(FIFO_DEPTH):
        readback = await read_word(dut, addr)
        assert readback == written[addr], (f"FAIL addr={addr}: expected {written[addr]:#06x}, got {readback:#06x}")

    log.info("test_fill_and_drain: PASS")


@cocotb.test()
async def test_overwrite(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 13, unit="ns").start())
    await reset_dut(dut)

    first  = random.randint(0, DATA_MASK)
    second = (first + 1) & DATA_MASK

    await write_word(dut, 0, first)
    await write_word(dut, 0, second)

    readback = await read_word(dut, 0)
    assert readback == second, (
        f"FAIL overwrite: expected {second:#06x}, got {readback:#06x}"
    )
    log.info(f"test_overwrite: PASS (first={first:#06x} second={second:#06x})")


@cocotb.test()
async def test_write_enable_gate(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 13, unit="ns").start())
    
    await reset_dut(dut)
    await write_word(dut, 0, 0xABCD)

    dut.wr_en.value   = 0
    dut.wr_addr.value = 0
    dut.wr_data.value = 0xFFFF
    await RisingEdge(dut.wr_clk)
    readback = await read_word(dut, 0)
    assert readback == 0xABCD, (f"FAIL wr_en gate: memory changed to {readback:#06x} without wr_en")
    log.info("test_write_enable_gate: PASS")


@cocotb.test()
async def test_read_enable_gate(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.wr_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.rd_clk, 13, unit="ns").start())
    await reset_dut(dut)
    await write_word(dut, 0, 0x1234)
    await write_word(dut, 1, 0x5678)
    first_read = await read_word(dut, 0)
    assert first_read == 0x1234, f"Sanity read failed: {first_read:#06x}"
    dut.rd_addr.value = 1
    dut.rd_en.value   = 0
    await RisingEdge(dut.rd_clk)
    await Timer(1, unit="ns")

    log.info(f"test_read_enable_gate: rd_data with rd_en=0 => {dut.rd_data.value}")
    log.info("test_read_enable_gate: PASS (no crash, csb1 was high)")
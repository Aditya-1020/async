import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

DATA_WIDTH = 8
FIFO_DEPTH = 16


"""
sync_fifo ports:
    input  wire clk
    input  wire rst_n
    input  wire wr_en
    input  wire rd_en
    input  wire [DATA_WIDTH-1:0] wr_data
    output wire [DATA_WIDTH-1:0] rd_data   <-- never drive this
    output wire full
    output wire empty
    output wire overflow
    output wire underflow
"""
async def fifo_write(dut, data):
    dut.wr_en.value   = 1
    dut.wr_data.value = data
    await RisingEdge(dut.clk)
    dut.wr_en.value   = 0
    await Timer(1, unit="ns")


async def fifo_read(dut):
    await Timer(1, unit="ns")
    readback = dut.rd_data.value.to_unsigned()
    dut.rd_en.value = 1
    await RisingEdge(dut.clk)
    dut.rd_en.value = 0
    await Timer(1, unit="ns")
    return readback


async def reset_dut(dut):
    dut.wr_en.value   = 0
    dut.rd_en.value   = 0
    dut.wr_data.value = 0
    dut.rst_n.value   = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value   = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.empty.value == 1, "FAIL: not empty after reset"
    assert dut.full.value  == 0, "FAIL: full asserted after reset"

@cocotb.test()
async def test_write_read_sequential(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    log.info("test_write_read_sequential: start")
    for _ in range(FIFO_DEPTH // 2):
        data = random.randint(0, 2**DATA_WIDTH - 1)
        await fifo_write(dut, data)
        readback = await fifo_read(dut)
        assert readback == data, f"expected {data:#04x} got {readback:#04x}"
        log.info(f"  wrote {data:#04x} read {readback:#04x} OK")

    log.info("test_write_read_sequential: PASS")

@cocotb.test()
async def test_fill_and_drain(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    written = [0] * FIFO_DEPTH

    log.info("test_fill_and_drain: filling")
    for i in range(FIFO_DEPTH):
        assert dut.full.value == 0, f"FAIL: full too early after {i} writes"
        written[i] = random.randint(0, 2**DATA_WIDTH - 1)
        await fifo_write(dut, written[i])
        log.info(f"  wrote [{i}] {written[i]:#04x}")

    assert dut.full.value  == 1, "FAIL: full not asserted after max writes"
    assert dut.empty.value == 0, "FAIL: empty asserted when full"
    log.info("test_fill_and_drain: full OK")

    log.info("test_fill_and_drain: draining")
    for i in range(FIFO_DEPTH):
        assert dut.empty.value == 0, f"FAIL: empty too early after {i} reads"
        readback = await fifo_read(dut)
        assert readback == written[i], (f"FAIL [{i}]: expected {written[i]:#04x} got {readback:#04x}")
        log.info(f"  read [{i}] {readback:#04x} OK")

    assert dut.empty.value == 1, "FAIL: not empty after full drain"
    assert dut.full.value  == 0, "FAIL: full still asserted after drain"
    log.info("test_fill_and_drain: PASS")

@cocotb.test()
async def test_overflow(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    for _ in range(FIFO_DEPTH):
        await fifo_write(dut, 0xAA)

    assert dut.full.value == 1, "FAIL: not full before overflow test"
    dut.wr_en.value   = 1
    dut.wr_data.value = 0xFF
    await Timer(1, unit="ns")
    assert dut.overflow.value == 1, "FAIL: overflow did not assert"
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0

    await Timer(1, unit="ns")
    assert dut.full.value  == 1, "FAIL: full deasserted after overflow write"
    assert dut.empty.value == 0, "FAIL: empty asserted after overflow write"

    log.info("test_overflow: PASS")

@cocotb.test()
async def test_underflow(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    assert dut.empty.value == 1, "FAIL: not empty before underflow test"

    dut.rd_en.value = 1
    await Timer(1, unit="ns")
    assert dut.underflow.value == 1, "FAIL: underflow did not assert"
    await RisingEdge(dut.clk)
    dut.rd_en.value = 0

    await Timer(1, unit="ns")
    assert dut.empty.value == 1, "FAIL: empty deasserted after underflow read"

    log.info("test_underflow: PASS")

@cocotb.test()
async def test_simultaneous_rw(dut):
    log = dut._log
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    half = FIFO_DEPTH // 2

    prefill = [random.randint(0, 2**DATA_WIDTH - 1) for _ in range(half)]
    for d in prefill:
        await fifo_write(dut, d)

    log.info("test_simultaneous_rw: start concurrent r/w")
    expected = list(prefill)

    for _ in range(half):
        new_data = random.randint(0, 2**DATA_WIDTH - 1)
        expected.append(new_data)

        await Timer(1, unit="ns")
        readback = dut.rd_data.value.to_unsigned()

        dut.wr_en.value   = 1
        dut.wr_data.value = new_data
        dut.rd_en.value   = 1
        await RisingEdge(dut.clk)
        dut.wr_en.value = 0
        dut.rd_en.value = 0
        await Timer(1, unit="ns")

        exp = expected.pop(0)
        assert readback == exp, f"FAIL: expected {exp:#04x} got {readback:#04x}"
        log.info(f"  rw: read {readback:#04x} wrote {new_data:#04x} OK")

    log.info("test_simultaneous_rw: PASS")
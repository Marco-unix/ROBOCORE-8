# SPDX-License-Identifier: Apache-2.0
"""Behavioral checks for ROBOCORE-8 dedicated 8-in / 8-out design."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

async def tick(dut, n=2):
    await ClockCycles(dut.clk, n)
    await Timer(1, unit="ns")

def vector(front=0, left=0, right=0, auto=1, cmd=0, arm=1, hb=0):
    return (front | (left << 1) | (right << 2) | (auto << 3)
            | (cmd << 4) | (arm << 6) | (hb << 7))

def check(dut, motors, brake=None, link=None):
    o = int(dut.uo_out.value)
    assert (o & 0x0F) == motors, f"motors={o&15:04b}, expected={motors:04b}"
    if brake is not None:
        assert bool(o & 0x10) == bool(brake), f"brake bit unexpected, out={o:08b}"
    if link is not None:
        assert bool(o & 0x40) == bool(link), f"link bit unexpected, out={o:08b}"
    assert int(dut.uio_oe.value) == 0
    assert int(dut.uio_out.value) == 0

@cocotb.test()
async def test_robocore(dut):
    cocotb.start_soon(Clock(dut.clk, 1000, unit="ns").start())  # 1 MHz nominal
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = vector()
    dut.uio_in.value = 0
    await tick(dut, 3)
    check(dut, 0, brake=True, link=False)
    dut.rst_n.value = 1
    await tick(dut)
    check(dut, 0, brake=True, link=False)  # No motion before heartbeat

    dut.ui_in.value = vector(hb=1)
    await tick(dut)
    check(dut, 0b0011, brake=False, link=True)  # forward

    dut.ui_in.value = vector(front=1, hb=1)
    await tick(dut)
    check(dut, 0b0110, brake=False, link=True)  # left pivot
    assert (int(dut.uo_out.value) & 0x20) != 0

    dut.ui_in.value = vector(front=1, left=1, hb=1)
    await tick(dut)
    check(dut, 0b1001, brake=False, link=True)  # right pivot

    dut.ui_in.value = vector(front=1, left=1, right=1, hb=1)
    await tick(dut)
    check(dut, 0, brake=True, link=True)  # all blocked

    # Manual forward blocked by front obstacle.
    dut.ui_in.value = vector(front=1, auto=0, cmd=1, hb=1)
    await tick(dut)
    check(dut, 0, brake=True)
    dut.ui_in.value = vector(auto=0, cmd=1, hb=1)
    await tick(dut)
    check(dut, 0b0011, brake=False)
    dut.ui_in.value = vector(auto=0, cmd=2, hb=1)
    await tick(dut)
    check(dut, 0b0110, brake=False)
    dut.ui_in.value = vector(auto=0, cmd=3, hb=1)
    await tick(dut)
    check(dut, 0b1001, brake=False)

    # Disarm immediately, and demand a NEW heartbeat edge when rearmed.
    dut.ui_in.value = vector(auto=1, arm=0, hb=1)
    await tick(dut)
    check(dut, 0, brake=True, link=False)
    dut.ui_in.value = vector(auto=1, arm=1, hb=1)
    await tick(dut)
    check(dut, 0, brake=True, link=False)
    dut.ui_in.value = vector(auto=1, arm=1, hb=0)
    await tick(dut)
    check(dut, 0b0011, brake=False, link=True)

    # Heartbeat stalls. Watchdog times out within 1024 clocks.
    await tick(dut, 1026)
    check(dut, 0, brake=True, link=False)
    # New edge recovers.
    dut.ui_in.value = vector(auto=1, hb=1)
    await tick(dut)
    check(dut, 0b0011, brake=False, link=True)
    dut.ena.value = 0
    await tick(dut)
    check(dut, 0, brake=True, link=False)

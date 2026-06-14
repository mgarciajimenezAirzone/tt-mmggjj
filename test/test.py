# SPDX-FileCopyrightText: 2024 Mario Garcia Jimenez
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def reset(dut):
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


@cocotb.test()
async def test_normal_mode(dut):
    """Test 1: Modo normal - suma 8 + 3 = 11"""
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    dut.ui_in.value  = (8 << 2) & 0xFF
    dut.uio_in.value = 3

    await ClockCycles(dut.clk, 20)  # mas ciclos para gate-level timing

    result_bits = (int(dut.uo_out.value) >> 3) & 0x1F
    cocotb.log.info(f"8 + 3 = {result_bits} (esperado 11)")
    assert result_bits == 11, f"Error: esperado 11, obtenido {result_bits}"


@cocotb.test()
async def test_bist_pass(dut):
    """Test 2: BIST sin fallo - debe terminar con PASS"""
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    dut.ui_in.value  = 0b00000001
    dut.uio_in.value = 0

    for _ in range(5000):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 2) & 1:
            break

    bist_done = (int(dut.uo_out.value) >> 2) & 1
    bist_pass = (int(dut.uo_out.value) >> 0) & 1
    bist_fail = (int(dut.uo_out.value) >> 1) & 1

    cocotb.log.info(f"BIST done={bist_done}, pass={bist_pass}, fail={bist_fail}")
    assert bist_done == 1, "BIST no termino"
    assert bist_pass == 1, "BIST deberia dar PASS"
    assert bist_fail == 0, "BIST no deberia dar FAIL"


@cocotb.test()
async def test_bist_fault_detected(dut):
    """Test 3: BIST con fault_inject - debe detectar FAIL"""
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    dut.ui_in.value  = 0b00000011
    dut.uio_in.value = 0

    for _ in range(5000):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 2) & 1:
            break

    bist_done = (int(dut.uo_out.value) >> 2) & 1
    bist_pass = (int(dut.uo_out.value) >> 0) & 1
    bist_fail = (int(dut.uo_out.value) >> 1) & 1

    cocotb.log.info(f"BIST fault: done={bist_done}, pass={bist_pass}, fail={bist_fail}")
    assert bist_done == 1, "BIST no termino"
    assert bist_fail == 1, "BIST deberia detectar FAIL con fault_inject"
    assert bist_pass == 0, "BIST no deberia dar PASS con fallo"

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
    """Test 1: Modo normal - verifica que bist_pass=0 y bist_fail=0 en modo normal"""
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    # En modo normal bist_en=0, los flags BIST deben estar a 0
    dut.ui_in.value  = 0  # bist_en=0
    dut.uio_in.value = 0

    await ClockCycles(dut.clk, 10)

    bist_pass = (int(dut.uo_out.value) >> 0) & 1
    bist_fail = (int(dut.uo_out.value) >> 1) & 1
    bist_done = (int(dut.uo_out.value) >> 2) & 1

    cocotb.log.info(f"Modo normal: pass={bist_pass}, fail={bist_fail}, done={bist_done}")
    assert bist_pass == 0, "En modo normal bist_pass debe ser 0"
    assert bist_fail == 0, "En modo normal bist_fail debe ser 0"
    assert bist_done == 0, "En modo normal bist_done debe ser 0"


@cocotb.test()
async def test_bist_pass(dut):
    """Test 2: BIST sin fallo - debe terminar con PASS"""
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    dut.ui_in.value  = 0b00000001  # bist_en=1
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

    dut.ui_in.value  = 0b00000011  # bist_en=1, fault_inject=1
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

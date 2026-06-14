# SPDX-FileCopyrightText: 2024 Mario Garcia Jimenez
# SPDX-License-Identifier: Apache-2.0

"""
Testbench cocotb para BIST-8
Compatible con el framework de Tiny Tapeout (ttihp-verilog-template)

Tests:
  1. Normal mode: verifica suma 8+3=11
  2. BIST mode sin fallo: espera PASS, firma 0xD48D
  3. BIST mode con fault_inject: espera FAIL
"""

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
    clock = Clock(dut.clk, 100, units="ns")  # 10MHz
    cocotb.start_soon(clock.start())

    await reset(dut)

    # bist_en=0, fault_inject=0, a_in=8 (bits 7:2 de ui_in)
    # a_in[5:0] en ui_in[7:2], b_in en uio_in[5:0]
    dut.ui_in.value  = (8 << 2) & 0xFF   # a=8, bist_en=0
    dut.uio_in.value = 3                  # b=3

    await ClockCycles(dut.clk, 2)

    result_bits = (dut.uo_out.value >> 3) & 0x1F
    cocotb.log.info(f"8 + 3 = {result_bits} (esperado 11)")
    assert result_bits == 11, f"Error: esperado 11, obtenido {result_bits}"


@cocotb.test()
async def test_bist_pass(dut):
    """Test 2: BIST sin fallo - debe terminar con PASS"""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    # bist_en=1, fault_inject=0
    dut.ui_in.value  = 0b00000001  # bist_en=1
    dut.uio_in.value = 0

    # Esperar bist_done (bit 2 de uo_out) — max 4095 + margen ciclos
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if (dut.uo_out.value >> 2) & 1:
            break

    bist_done = (dut.uo_out.value >> 2) & 1
    bist_pass = (dut.uo_out.value >> 0) & 1
    bist_fail = (dut.uo_out.value >> 1) & 1

    cocotb.log.info(f"BIST done={bist_done}, pass={bist_pass}, fail={bist_fail}")
    assert bist_done == 1, "BIST no terminó"
    assert bist_pass == 1, "BIST debería dar PASS"
    assert bist_fail == 0, "BIST no debería dar FAIL"


@cocotb.test()
async def test_bist_fault_detected(dut):
    """Test 3: BIST con fault_inject - debe detectar FAIL"""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset(dut)

    # bist_en=1, fault_inject=1
    dut.ui_in.value  = 0b00000011  # bist_en=1, fault_inject=1
    dut.uio_in.value = 0

    for _ in range(5000):
        await RisingEdge(dut.clk)
        if (dut.uo_out.value >> 2) & 1:
            break

    bist_done = (dut.uo_out.value >> 2) & 1
    bist_pass = (dut.uo_out.value >> 0) & 1
    bist_fail = (dut.uo_out.value >> 1) & 1

    cocotb.log.info(f"BIST fault: done={bist_done}, pass={bist_pass}, fail={bist_fail}")
    assert bist_done == 1, "BIST no terminó"
    assert bist_fail == 1, "BIST debería detectar FAIL con fault_inject"
    assert bist_pass == 0, "BIST no debería dar PASS con fallo"

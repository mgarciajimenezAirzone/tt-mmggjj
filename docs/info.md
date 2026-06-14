# BIST-8: Built-In Self-Test for 8-bit CLA Adder

## Overview

BIST-8 implements a complete Built-In Self-Test architecture targeting an 8-bit
Carry-Lookahead Adder (CLA) as the Circuit Under Test (CUT). The design
demonstrates core BIST concepts applicable to arithmetic circuits and is part of
a Master's Thesis on test methodologies at IMSE-CNM-CSIC / Universidad de Sevilla.

## Architecture

```
         bist_en=0 (normal mode)
         ┌────────────────────────────┐
         │  a_in[7:0]  b_in[7:0]     │
         │       ↓         ↓         │
         │  ┌──────────────────┐     │
         │  │  CLA Adder 8-bit │     │
         │  │  (2x 4-bit CLA)  │     │
         │  └────────┬─────────┘     │
         │           │ sum[8:0]      │
         └───────────┼───────────────┘
                     │
         bist_en=1 (BIST mode)
         ┌───────────┼───────────────┐
         │  ┌────────┴─────────┐    │
         │  │  LFSR 12-bit     │    │
         │  │  poly: x¹²+x¹¹  │    │
         │  │       +x¹⁰+x⁴+1 │    │
         │  │  4095 vectors    │    │
         │  └────────┬─────────┘    │
         │           │ {a,b}        │
         │  ┌────────┴─────────┐    │
         │  │  CLA Adder (CUT) │    │
         │  └────────┬─────────┘    │
         │           │ response     │
         │  ┌────────┴─────────┐    │
         │  │  MISR 16-bit     │    │
         │  │  poly: x¹⁶+x¹⁵  │    │
         │  │       +x²+1      │    │
         │  └────────┬─────────┘    │
         │           │ signature    │
         │  ┌────────┴─────────┐    │
         │  │ Compare vs 0xD48D│    │
         │  └────────┬─────────┘    │
         │           │              │
         │      PASS / FAIL         │
         └──────────────────────────┘
```

## Components

### Test Pattern Generator (TPG)
- 12-bit LFSR with primitive polynomial x¹²+x¹¹+x¹⁰+x⁴+1
- Maximum-length sequence: 4095 unique test vectors
- Seed: 0xACE

### Circuit Under Test (CUT)
- 8-bit Carry-Lookahead Adder, two 4-bit CLA groups
- Full carry propagation with generate/propagate logic
- Fault injection: forces bit 3 to stuck-at-0 when `fault_inject=1`

### Multiple Input Signature Register (MISR)
- 16-bit MISR with polynomial x¹⁶+x¹⁵+x²+1
- Compacts 4095 × 9-bit responses into a 16-bit signature
- Aliasing probability: 2⁻¹⁶ ≈ 0.0015%
- Golden signature: 0xD48D

### FSM Controller
- 4 states: IDLE → BIST_RUN → COMPARE → DONE
- Cycle counter exported for observability
- Returns to IDLE on bist_en deassertion

## How to Test

### Normal Mode (bist_en = 0)
1. Set `ui_in[0] = 0`
2. Apply operand A on `ui_in[7:2]` + `uio_in[7:6]`
3. Apply operand B on `uio_in[5:0]`
4. Read result on `uo_out[7:3]` (bits 7:3 of sum)

### BIST Mode (bist_en = 1)
1. Assert reset (`rst_n = 0` then `rst_n = 1`)
2. Set `ui_in[0] = 1`, `ui_in[1] = 0` (no fault injection)
3. Wait for `uo_out[2] = 1` (bist_done) — takes 4095 clock cycles
4. Check: `uo_out[0] = 1` (PASS) and `uo_out[1] = 0` (FAIL)
5. Monitor `uio_out[7:0]` for cycle counter

### Fault Injection Test
1. Assert reset
2. Set `ui_in[0] = 1`, `ui_in[1] = 1` (enable fault injection)
3. Wait for `uo_out[2] = 1` (bist_done)
4. Expected: `uo_out[1] = 1` (FAIL detected)

## Technical Details

| Parameter | Value |
|-----------|-------|
| LFSR polynomial | x¹²+x¹¹+x¹⁰+x⁴+1 |
| LFSR seed | 0xACE |
| MISR polynomial | x¹⁶+x¹⁵+x²+1 |
| Golden signature | 0xD48D |
| Test vectors | 4095 |
| MISR aliasing prob. | 2⁻¹⁶ ≈ 0.0015% |
| Fault model | Stuck-at-0, bit 3 of sum |

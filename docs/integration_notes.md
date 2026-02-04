# Integration Notes - Digital Musical Instrument

## Overview

This document provides integration guidelines, timing constraints, simulation instructions, and troubleshooting tips for the digital musical instrument Caravel user project.

---

## Clock and Reset Architecture

### System Clock
- **Source:** `wb_clk_i` from Caravel management SoC
- **Frequency:** Configurable, typically 25-50 MHz
- **Distribution:** Single clock domain for all logic
- **Domain:** Synchronous design, no clock domain crossings

### Sample Rate Generation
The audio sample rate is derived from the system clock using a programmable divider:

```
Sample_Rate = wb_clk_i / CLK_DIV

For 48 kHz @ 48 MHz: CLK_DIV = 1000
For 48 kHz @ 50 MHz: CLK_DIV = 1042 (actual: 47.97 kHz)
For 48 kHz @ 25 MHz: CLK_DIV = 521 (actual: 47.98 kHz)
```

**Configuration Register:** `SYNTHESIZER.CLK_DIV` (0x3004_0004)

### Reset
- **Source:** `wb_rst_i` from Caravel (active high, synchronous)
- **Type:** Synchronous reset to `wb_clk_i`
- **Distribution:** Direct fanout to all modules
- **Assertion:** System initializes on reset deassertion

**Reset Sequence:**
1. All FIFOs cleared
2. All voices silenced (ADSR released, oscillators muted)
3. GPIO configured as inputs (safe state)
4. Wishbone slaves ready to accept transactions
5. Interrupts cleared and masked

---

## Bus Timing and Wishbone Protocol

### Wishbone B4 (Classic) Interface
All peripherals implement Wishbone B4 classic single-cycle protocol.

**Handshake Timing:**
```
Cycle:  0    1    2    3    4
        ___  ___  ___  ___  ___
CLK   _/   \/   \/   \/   \/   \

CYC   ______/‾‾‾‾‾‾‾‾‾‾‾‾\_____
STB   ______/‾‾‾‾‾‾‾‾‾‾‾‾\_____
WE    ______/‾‾‾‾‾‾‾‾‾‾‾‾\_____
ADR   ======<  ADDR   >========
DAT_I ======<  DATA   >========
ACK   ____________/‾‾\__________
```

**Key Characteristics:**
- **Read latency:** 1 cycle (ACK asserted cycle after STB/CYC)
- **Write latency:** 1 cycle
- **Pipeline:** No pipelining (classic mode)
- **Termination:** All accesses must be ACKed or ERRed

### Address Decode
- **Base:** 0x3000_0000 (Caravel user project area)
- **Decode bits:** `wbs_adr_i[19:16]` selects peripheral (0-10)
- **Window size:** 64 KB per peripheral
- **Invalid access:** Returns 0xDEADBEEF on reads, ACK but discard on writes

**Important:** Never gate `wbs_cyc_i`. Only gate `wbs_stb_i` for peripheral selection.

---

## Interrupt Architecture

### IRQ Sources and Mapping
| **IRQ #** | **Source** | **Priority** | **Type** | **Description** |
|-----------|------------|--------------|----------|-----------------|
| IRQ0 | Keyboard | High | Edge | Key event FIFO not empty |
| IRQ1 | Audio | Medium | Level | I2S underrun or buffer threshold |
| IRQ2 | Theremin | Low | Level | ADC data ready |
| IRQ3-15 | Reserved | - | - | Future expansion |

### Interrupt Flow
```
[Peripheral IRQ] → [WB_PIC] → [Priority Encode] → user_irq[0] → [Management SoC]
                     16 sources    Masked
```

**Handling:**
1. Management SoC receives `user_irq[0]`
2. Firmware reads WB_PIC.STATUS (0x3009_0004) to identify source
3. Firmware services the interrupt:
   - Keyboard: Read event FIFO (0x3002_0008)
   - Audio: Check I2S FIFO status, refill if needed
   - Theremin: Read modulation values (0x3006_0010, 0x3006_0014)
4. Firmware clears interrupt flag: Write 1 to WB_PIC.CLEAR (0x3009_000C)

**Configuration:**
- Enable interrupts: WB_PIC.MASK (0x3009_0008) = 0x0007 (IRQ0-2 enabled)
- Global enable: WB_PIC.CTRL (0x3009_0000) bit [0] = 1

---

## Audio Signal Path Timing

### Sample Rate Pipeline
At 48 kHz sample rate (20.83 µs per sample):

**Stage 1: Wavetable Oscillator (8 voices in parallel)**
- Phase accumulation: 1 cycle per voice
- SRAM read: 1-2 cycles
- Interpolation: 5-10 cycles
- **Total:** ~10-15 cycles per voice

**Stage 2: ADSR Envelope (8 voices in parallel)**
- State machine update: 2-5 cycles
- Amplitude multiply: 3-5 cycles
- **Total:** ~5-10 cycles per voice

**Stage 3: Theremin Modulation (applied to all voices)**
- Pitch offset add: 1 cycle
- Volume multiply: 3 cycles
- **Total:** ~4 cycles

**Stage 4: Audio Mixer**
- 8-input adder tree: 8-12 cycles
- Pan multiply (L/R): 6 cycles
- Master volume: 3 cycles
- Saturation: 2 cycles
- **Total:** ~20-25 cycles

**Stage 5: I2S Output**
- FIFO write: 1 cycle
- Hardware serialization: background

**Total Pipeline:** ~40-60 cycles typical, ~100 cycles worst-case

**Margin:** At 48 MHz clock, 1000 cycles available per sample → **~900 cycle margin**

### Latency
- **Input to output:** ~3-5 samples (62-104 µs)
- **Keyboard press to audio:** ~10 ms (scanning + debounce + synthesis)

---

## Power and Performance

### Dynamic Power Optimization
1. **Voice Gating:** Inactive voices (no note assigned) have:
   - Phase accumulator disabled
   - SRAM reads gated
   - ADSR bypassed
   - **Power savings:** ~60-70% when < 4 voices active

2. **Sample Rate Scaling:** Lower sample rates reduce power:
   - 32 kHz: ~33% lower dynamic power than 48 kHz
   - 24 kHz: ~50% lower (but lower audio quality)

### Throughput
- **Wishbone bus:** Single peripheral access per cycle
- **SRAM bandwidth:** 1 access per cycle (shared among 8 voices via round-robin)
- **I2S output:** Hardware FIFO reduces CPU load

---

## Simulation and Verification

### Testbench Structure
All tests use **cocotb** (Python) + **Caravel testbench** environment.

**Test Location:** `verilog/dv/cocotb/`

**Test Categories:**
1. **Keyboard Scanner Tests** (`test_keyboard/`)
   - Matrix scanning
   - Velocity measurement
   - Event FIFO
   - Debounce

2. **Audio Synthesis Tests** (`test_audio/`)
   - Wavetable oscillator
   - ADSR envelope
   - Voice allocation
   - Mixer

3. **Theremin Tests** (`test_theremin/`)
   - SPI ADC interface
   - Data smoothing
   - Modulation application

4. **System Integration Test** (`test_integration/`)
   - Full end-to-end test
   - Firmware interaction
   - All peripherals active

### Running cocotb Tests

**Prerequisites:**
```bash
# Install cocotb
pip install cocotb cocotb-bus

# Install Caravel cocotb framework
# (Already available in NativeChips environment)
```

**Run Individual Test:**
```bash
cd verilog/dv/cocotb/test_keyboard
make
```

**Run All Tests:**
```bash
cd verilog/dv/cocotb
python cocotb_tests.py
```

**Waveform Viewing:**
```bash
gtkwave dump.vcd &
```

### Firmware Testing

**Test Firmware Location:** `fw/`

**Key Test Programs:**
1. **`smoke_test.c`:** Basic peripheral access and sanity checks
2. **`keyboard_test.c`:** Keyboard scanning and event handling
3. **`audio_test.c`:** Play test tones (sine wave, square wave)
4. **`integration_test.c`:** Full system test with keyboard input

**Compile Firmware:**
```bash
cd fw
make
```

**Run with Caravel-Cocotb:**
```bash
cd verilog/dv/cocotb/test_integration
make FIRMWARE=../../../../fw/integration_test.hex
```

---

## Gate-Level and SDF Simulation

### Gate-Level (GL) Simulation
After OpenLane synthesis, test with gate-level netlist:

**Configuration:** `verilog/dv/cocotb/design_info.yaml`
```yaml
  gl:
    toplevel: user_project_wrapper
    verilog_sources:
      - ../../../verilog/gl/user_project_wrapper.v
      - ../../../verilog/gl/user_project.v
    defines:
      - GL_TEST
      - FUNCTIONAL
```

**Run:**
```bash
make GL=1
```

### SDF Timing Simulation
For accurate timing with parasitics:

**Configuration:** Add to `design_info.yaml`
```yaml
  sdf:
    toplevel: user_project_wrapper
    sdf_file: ../../../sdf/user_project_wrapper.sdf
    defines:
      - SDF_TEST
```

**Run:**
```bash
make SDF=1
```

---

## Integration Checklist

### Pre-Integration
- [ ] All modules linted (Verilator --lint-only --Wno-EOFNEWLINE)
- [ ] Individual module testbenches pass
- [ ] Register map documented and reviewed
- [ ] Pad assignments finalized
- [ ] Wishbone address decode verified

### RTL Integration
- [ ] `user_project.v` instantiates all modules
- [ ] `user_project_wrapper.v` connects pads correctly
- [ ] Wishbone bus splitter configured for 10 peripherals
- [ ] WB_PIC interrupts mapped correctly
- [ ] Clock and reset properly distributed
- [ ] No combinational loops or latches

### Verification
- [ ] All cocotb tests pass at RTL level
- [ ] Firmware smoke test runs successfully
- [ ] Keyboard scanning functional
- [ ] Audio synthesis produces expected output
- [ ] Theremin modulation works correctly
- [ ] Interrupts trigger and clear properly
- [ ] GL simulation passes (post-synthesis)
- [ ] SDF timing simulation passes (if available)

### Physical Design
- [ ] OpenLane runs clean (no DRC/LVS errors)
- [ ] Timing closure achieved (no negative slack)
- [ ] Power analysis acceptable
- [ ] Pad ring matches design
- [ ] GDS generated successfully

---

## Common Issues and Troubleshooting

### Issue: Wishbone Transactions Hang
**Symptoms:** Bus access never completes, `wbs_ack_o` not asserted  
**Causes:**
- Peripheral not responding (check enable signals)
- Address decode error (invalid address not handled)
- `wbs_cyc_i` gated incorrectly

**Debug:**
1. Check waveforms for `wbs_cyc_i`, `wbs_stb_i`, `wbs_ack_o`
2. Verify address decode logic
3. Ensure all peripherals ACK within 1-2 cycles
4. Add timeout mechanism in testbench

### Issue: Audio Output Silent
**Symptoms:** No I2S data, or data is zero  
**Causes:**
- Synthesizer disabled
- Master mute enabled
- No voices allocated
- Wavetables not loaded
- Clock divider misconfigured

**Debug:**
1. Check SYNTHESIZER.CTRL enable bit
2. Verify CLK_DIV value (should be ~1000 for 48kHz @ 48MHz)
3. Check ADSR gate signals (should be high for active notes)
4. Read wavetable memory to confirm data loaded
5. Check mixer MASTER_VOL register

### Issue: Keyboard Not Responding
**Symptoms:** No events in FIFO, no interrupts  
**Causes:**
- Scanner disabled
- GPIO not configured correctly
- Debounce time too long
- Column pull-ups missing

**Debug:**
1. Check KEYBOARD_SCANNER.CTRL enable bit
2. Verify GPIO_0 (rows) DIR register = 0x3F (outputs)
3. Verify GPIO_1 (cols) DIR register = 0x00 (inputs)
4. Check SCAN_MAP register to see if scanning active
5. Manually toggle row GPIOs and read column GPIOs

### Issue: Interrupts Not Triggering
**Symptoms:** `user_irq[0]` never asserts  
**Causes:**
- WB_PIC global enable off
- IRQ source masked
- Interrupt flag not being set by peripheral

**Debug:**
1. Check WB_PIC.CTRL bit [0] = 1 (global enable)
2. Check WB_PIC.MASK = 0x0007 (IRQ0-2 enabled)
3. Read WB_PIC.STATUS to see which IRQs are pending
4. Check peripheral interrupt status registers
5. Verify IRQ lines are connected in `user_project.v`

### Issue: Timing Violations
**Symptoms:** OpenLane reports negative slack  
**Causes:**
- Long combinational paths
- High fanout signals
- Insufficient pipelining

**Solutions:**
1. Add pipeline registers in critical paths
2. Reduce logic depth between registers
3. Balance synthesizer voice processing
4. Lower target frequency if necessary
5. Use register retiming in synthesis

### Issue: GL Simulation Fails but RTL Passes
**Symptoms:** Gate-level netlist behaves differently  
**Causes:**
- Timing issues (setup/hold violations)
- X-propagation in simulation
- Missing power pins in instantiation

**Debug:**
1. Check for `X` values in waveforms
2. Run STA (static timing analysis) to find violations
3. Verify `USE_POWER_PINS` define is set
4. Check for race conditions or uninitialized registers

---

## Design Constraints (for OpenLane)

### Clock Constraints (SDC)
```tcl
# Base SDC for user_project

# Create clock
create_clock -name wb_clk_i -period 20.0 [get_ports wb_clk_i]

# Input delays (assume 5ns from Caravel management)
set_input_delay -clock wb_clk_i -max 5.0 [all_inputs]
set_input_delay -clock wb_clk_i -min 1.0 [all_inputs]

# Output delays (assume 5ns to Caravel management)
set_output_delay -clock wb_clk_i -max 5.0 [all_outputs]
set_output_delay -clock wb_clk_i -min 1.0 [all_outputs]

# Clock uncertainty (for on-chip variation)
set_clock_uncertainty -setup 0.5 [get_clocks wb_clk_i]
set_clock_uncertainty -hold 0.25 [get_clocks wb_clk_i]

# Set load on outputs (estimated)
set_load 0.5 [all_outputs]

# False paths (if any asynchronous signals)
# set_false_path -from [get_ports some_async_input]
```

### Area and Utilization
- **Target utilization:** 40-60% (for user_project macro)
- **Target utilization:** 20-30% (for user_project_wrapper)
- **Die area (user_project):** ~400µm × 400µm minimum
- **Die area (user_project_wrapper):** 3000µm × 3600µm (Caravel fixed)

---

## Performance Specifications

### Audio Quality
- **Sample rate:** 48 kHz
- **Bit depth:** 16-bit
- **Channels:** 2 (stereo)
- **THD+N:** <1% (limited by PWM/I2S DAC)
- **Dynamic range:** ~90 dB (theoretical, 16-bit)

### Polyphony
- **Voices:** 8 simultaneous
- **Voice stealing:** LRU algorithm
- **Latency:** <1 ms note-on to audio

### Keyboard
- **Keys:** 37 (3 octaves)
- **Scan rate:** ~1 kHz
- **Debounce:** Configurable (default 50 ms)
- **Velocity resolution:** 7-bit (0-127)

---

## References

### Internal Documents
- [Register Map](register_map.md)
- [Pad Map](pad_map.md)
- [Architecture Overview](architecture.md)
- [IP Gap Analysis](ip_gap_analysis.md)

### External IP Documentation
- EF_GPIO8: `/nc/ip/EF_GPIO8/README.md`
- CF_SRAM_1024x32: `/nc/ip/CF_SRAM_1024x32/README.md`
- EF_I2S: `/nc/ip/EF_I2S/README.md`
- CF_SPI: `/nc/ip/CF_SPI/README.md`

### Caravel Documentation
- Caravel User Project Template: https://github.com/efabless/caravel_user_project
- Caravel Harness: https://github.com/efabless/caravel

---

*Document Version: 1.0*  
*Last Updated: 2026-02-04*

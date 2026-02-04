# Pad Map - Digital Musical Instrument

## Caravel IO Overview

Caravel provides **38 user digital IO pads** (`mprj_io[37:0]`) that can be configured as inputs, outputs, or bidirectional signals.

**Reserved Pads (Do Not Use):**
- `mprj_io[4:0]` - Reserved for Caravel housekeeping/management

**Available Pads:**
- `mprj_io[37:5]` - 33 pads available for user project

---

## Pad Allocation Summary

| **Function** | **# Pads** | **Pad Range** | **Description** |
|--------------|------------|---------------|-----------------|
| Keyboard Matrix Rows | 6 | `mprj_io[10:5]` | Output - row scan signals |
| Keyboard Matrix Columns | 7 | `mprj_io[17:11]` | Input - column sense with pull-ups |
| I2S Audio Output | 3 | `mprj_io[20:18]` | Output - SCLK, WS, SD |
| SPI Theremin ADC | 4 | `mprj_io[24:21]` | SPI Master - SCK, MOSI, MISO, CS |
| Status LEDs | 2 | `mprj_io[26:25]` | Output - status indicators |
| **Total Used** | **22** | | |
| **Available** | **11** | `mprj_io[37:27]` | Reserved for future expansion |

---

## Detailed Pad Assignments

### Keyboard Matrix Interface

#### Row Outputs (6 pads)
| **Pad** | **Signal Name** | **Direction** | **Description** | **Default State** |
|---------|-----------------|---------------|-----------------|-------------------|
| mprj_io[5] | KEY_ROW[0] | Output | Keyboard row 0 scan | Low (inactive) |
| mprj_io[6] | KEY_ROW[1] | Output | Keyboard row 1 scan | Low (inactive) |
| mprj_io[7] | KEY_ROW[2] | Output | Keyboard row 2 scan | Low (inactive) |
| mprj_io[8] | KEY_ROW[3] | Output | Keyboard row 3 scan | Low (inactive) |
| mprj_io[9] | KEY_ROW[4] | Output | Keyboard row 4 scan | Low (inactive) |
| mprj_io[10] | KEY_ROW[5] | Output | Keyboard row 5 scan | Low (inactive) |

**Configuration:**
- Output enable (OEB): 0 (output mode)
- Drive strength: Standard
- Slew rate: Standard
- Pull-up/down: None

**Operation:**
- Scanner activates one row at a time (sets high)
- All other rows remain low
- Columns are read to detect key presses

#### Column Inputs (7 pads)
| **Pad** | **Signal Name** | **Direction** | **Description** | **Default State** |
|---------|-----------------|---------------|-----------------|-------------------|
| mprj_io[11] | KEY_COL[0] | Input | Keyboard column 0 sense | High (no key) |
| mprj_io[12] | KEY_COL[1] | Input | Keyboard column 1 sense | High (no key) |
| mprj_io[13] | KEY_COL[2] | Input | Keyboard column 2 sense | High (no key) |
| mprj_io[14] | KEY_COL[3] | Input | Keyboard column 3 sense | High (no key) |
| mprj_io[15] | KEY_COL[4] | Input | Keyboard column 4 sense | High (no key) |
| mprj_io[16] | KEY_COL[5] | Input | Keyboard column 5 sense | High (no key) |
| mprj_io[17] | KEY_COL[6] | Input | Keyboard column 6 sense | High (no key) |

**Configuration:**
- Output enable (OEB): 1 (input mode)
- Pull-up: External (recommended) or internal weak pull-up
- Schmitt trigger: Enabled (for noise immunity)

**Key Matrix Mapping (6×7 = 42 positions, 37 keys used):**
```
        COL0   COL1   COL2   COL3   COL4   COL5   COL6
ROW0:   Key0   Key1   Key2   Key3   Key4   Key5   Key6
ROW1:   Key7   Key8   Key9   Key10  Key11  Key12  Key13
ROW2:   Key14  Key15  Key16  Key17  Key18  Key19  Key20
ROW3:   Key21  Key22  Key23  Key24  Key25  Key26  Key27
ROW4:   Key28  Key29  Key30  Key31  Key32  Key33  Key34
ROW5:   Key35  Key36  (NC)   (NC)   (NC)   (NC)   (NC)

Key Numbering: 0-36 (37 keys total for 3 octaves)
Musical Mapping: Key0 = C3, Key36 = C6
```

---

### I2S Audio Output (3 pads)

| **Pad** | **Signal Name** | **Direction** | **Description** | **Default State** |
|---------|-----------------|---------------|-----------------|-------------------|
| mprj_io[18] | I2S_SCLK | Output | I2S bit clock (BCLK) | Low |
| mprj_io[19] | I2S_WS | Output | I2S word select (LRCLK) | Low |
| mprj_io[20] | I2S_SD | Output | I2S serial data | Low |

**Configuration:**
- Output enable (OEB): 0 (output mode)
- Drive strength: Standard or high (for signal integrity)
- Slew rate: Fast (for clean clock edges)

**I2S Timing (48 kHz, 16-bit stereo):**
- **SCLK frequency:** 48 kHz × 2 channels × 16 bits = 1.536 MHz
- **WS frequency:** 48 kHz (left/right channel select)
- **Format:** I2S standard (MSB first, WS transitions before MSB)

**External Connection:**
- Connect to external I2S DAC (e.g., PCM5102, CS4344, UDA1334)
- Requires external 3.3V or 5V DAC with analog output
- Add decoupling capacitors and LC filter for clean audio

---

### SPI Theremin ADC Interface (4 pads)

| **Pad** | **Signal Name** | **Direction** | **Description** | **Default State** |
|---------|-----------------|---------------|-----------------|-------------------|
| mprj_io[21] | SPI_SCK | Output | SPI clock | Low |
| mprj_io[22] | SPI_MOSI | Output | SPI master out, slave in | Low |
| mprj_io[23] | SPI_MISO | Input | SPI master in, slave out | High-Z |
| mprj_io[24] | SPI_CS_N | Output | SPI chip select (active low) | High (inactive) |

**Configuration:**
- SCK, MOSI, CS_N:
  - Output enable (OEB): 0 (output mode)
  - Drive strength: Standard
  - Slew rate: Standard
- MISO:
  - Output enable (OEB): 1 (input mode)
  - Pull-up: External (recommended)

**Recommended External ADC:**
- **MCP3202:** 12-bit, 2-channel ADC, SPI interface
- **ADS7883:** 12-bit, single-channel, 3 Msps
- **MCP3208:** 12-bit, 8-channel (for future expansion)

**SPI Configuration:**
- Mode: SPI Mode 0 (CPOL=0, CPHA=0)
- Clock frequency: 1-2 MHz (adjustable)
- Data order: MSB first

**Theremin Sensor Connection:**
- Channel 0: Pitch antenna (capacitive/distance sensor)
- Channel 1: Volume antenna (capacitive/distance sensor)
- Alternative: Use ultrasonic sensors with analog output

---

### Status LEDs (2 pads)

| **Pad** | **Signal Name** | **Direction** | **Description** | **Default State** |
|---------|-----------------|---------------|-----------------|-------------------|
| mprj_io[25] | STATUS_LED0 | Output | System status / power indicator | Low (off) |
| mprj_io[26] | STATUS_LED1 | Output | Activity indicator / error | Low (off) |

**Configuration:**
- Output enable (OEB): 0 (output mode)
- Drive strength: Standard (sufficient for LED with series resistor)
- Slew rate: Standard

**Usage:**
- **LED0:** Power on / system ready indicator (steady on)
- **LED1:** Audio activity / note playing indicator (blinks with audio)

**External Circuit:**
- Connect LED in series with current-limiting resistor (e.g., 330Ω for 3.3V, ~10mA)
- LED anode to pad, cathode to resistor, resistor to GND

---

### Reserved for Future Expansion (11 pads)

| **Pad Range** | **Potential Use** |
|---------------|-------------------|
| mprj_io[37:27] | UART for MIDI I/O, additional control inputs, expression pedal, sustain pedal, additional SPI devices, external memory interface |

---

## Pad Configuration in Verilog

### user_project_wrapper.v Pad Connection Example

```verilog
// Keyboard Matrix Rows (Outputs)
assign mprj_io_out[5] = key_row[0];
assign mprj_io_oeb[5] = 1'b0;  // Output enable
assign mprj_io_out[6] = key_row[1];
assign mprj_io_oeb[6] = 1'b0;
// ... (repeat for rows 2-5)

// Keyboard Matrix Columns (Inputs)
assign key_col[0] = mprj_io_in[11];
assign mprj_io_out[11] = 1'b0;
assign mprj_io_oeb[11] = 1'b1;  // Input mode
// ... (repeat for columns 1-6)

// I2S Audio (Outputs)
assign mprj_io_out[18] = i2s_sclk;
assign mprj_io_oeb[18] = 1'b0;
assign mprj_io_out[19] = i2s_ws;
assign mprj_io_oeb[19] = 1'b0;
assign mprj_io_out[20] = i2s_sd;
assign mprj_io_oeb[20] = 1'b0;

// SPI (Master)
assign mprj_io_out[21] = spi_sck;
assign mprj_io_oeb[21] = 1'b0;
assign mprj_io_out[22] = spi_mosi;
assign mprj_io_oeb[22] = 1'b0;
assign spi_miso = mprj_io_in[23];
assign mprj_io_out[23] = 1'b0;
assign mprj_io_oeb[23] = 1'b1;  // Input
assign mprj_io_out[24] = spi_cs_n;
assign mprj_io_oeb[24] = 1'b0;

// Status LEDs (Outputs)
assign mprj_io_out[25] = status_led0;
assign mprj_io_oeb[25] = 1'b0;
assign mprj_io_out[26] = status_led1;
assign mprj_io_oeb[26] = 1'b0;

// Unused pads (tie off)
assign mprj_io_out[37:27] = 11'b0;
assign mprj_io_oeb[37:27] = 11'h7FF;  // All inputs (high-Z)
```

---

## External Hardware Requirements

### Keyboard Matrix
- **Physical keyboard:** 37-key mechanical or membrane switch matrix
- **Diodes:** 1N4148 diodes on each switch (prevents ghosting)
- **Pull-up resistors:** 10kΩ on each column line (if not using internal)

### I2S DAC
- **DAC IC:** PCM5102A, CS4344, or UDA1334A
- **Power supply:** 3.3V or 5V (depending on DAC)
- **Decoupling:** 100nF ceramic + 10µF electrolytic capacitors
- **Output filter:** Optional RC filter (100Ω + 100nF) for noise reduction
- **Analog output:** Line-level or headphone output

### SPI ADC for Theremin
- **ADC IC:** MCP3202 (12-bit, 2-channel)
- **Capacitive sensors:** Metal antennas (10-30cm length) with sensing circuitry
- **Alternative:** HC-SR04 ultrasonic distance sensors (analog output mod)
- **Power supply:** 3.3V or 5V
- **Reference voltage:** 3.3V for full-scale ADC range

### Status LEDs
- **LEDs:** Standard 3mm or 5mm LEDs (red, green, or blue)
- **Current-limiting resistors:** 330Ω (for 3.3V, ~10mA)

---

## PCB Design Considerations

### Signal Integrity
1. **I2S signals:** Keep traces short and equal length for SCLK, WS, SD
2. **SPI signals:** Keep traces short, add series termination resistors (22-33Ω) if needed
3. **Keyboard matrix:** Use anti-ghosting diodes on every key

### Power Distribution
1. **Decoupling:** Place 100nF capacitors near each IC
2. **Power planes:** Use solid ground plane, separate analog/digital grounds if possible
3. **Audio DAC:** Isolate analog supply from digital switching noise

### EMI/Noise
1. **Shielding:** Consider shielded enclosure for audio sections
2. **Filtering:** Add ferrite beads on power lines to audio DAC
3. **Grounding:** Single-point ground for audio analog section

---

## Testability

### Debug Access Points
- Expose keyboard row/column signals on test points
- Expose I2S signals on test points for logic analyzer access
- Expose SPI signals for ADC debugging

### JTAG/Debug (Future)
- Consider reserving pads for JTAG or UART debug interface
- Use `mprj_io[37:35]` for potential UART TX/RX

---

## Modification Guide

### To Add/Remove Pads:
1. Update this pad_map.md document
2. Modify `verilog/rtl/user_project_wrapper.v` pad connections
3. Update `docs/integration_notes.md` with changes
4. Regenerate any HDL or constraints affected

### To Change Pad Assignments:
1. Ensure no conflicts with reserved pads
2. Update all references in RTL and documentation
3. Update firmware header files with new pad numbers

---

*Document Version: 1.0*  
*Last Updated: 2026-02-04*

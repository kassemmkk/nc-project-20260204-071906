# System Architecture - Digital Musical Instrument

## Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CARAVEL MANAGEMENT SOC                              │
│                     (Wishbone Master @ 0x3000_0000)                          │
└────────────────────────────────────────┬────────────────────────────────────┘
                                         │ Wishbone Bus
                                         │
                    ┌────────────────────▼────────────────────┐
                    │   WISHBONE BUS SPLITTER                 │
                    │   (10 peripherals, non-power-of-2)      │
                    └─┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──────────┘
                      │  │  │  │  │  │  │  │  │  │
      ┌───────────────┘  │  │  │  │  │  │  │  │  └────────────────┐
      │                  │  │  │  │  │  │  │  │                   │
┌─────▼─────┐   ┌────────▼────┐  │  │  │  │  │  │           ┌─────▼─────┐
│  GPIO_0   │   │   GPIO_1    │  │  │  │  │  │  │           │  WB_PIC   │
│ (EF_GPIO8)│   │ (EF_GPIO8)  │  │  │  │  │  │  │           │   (IRQ    │
│           │   │             │  │  │  │  │  │  │           │  Control) │
│ 8 pins    │   │  8 pins     │  │  │  │  │  │  │           └────┬──────┘
└───┬───┬───┘   └───┬───┬─────┘  │  │  │  │  │  │                │IRQ[2:0]
    │   │           │   │         │  │  │  │  │  │                │
    │   │           │   │         │  │  │  │  │  │                │
┌───▼───▼───────────▼───▼───┐     │  │  │  │  │  │                │
│   KEYBOARD SCANNER         │     │  │  │  │  │  │                │
│   (Custom RTL)             │     │  │  │  │  │  │                │
│                            │     │  │  │  │  │  │                │
│ • 6×7 matrix (37 keys)     │     │  │  │  │  │  │                │
│ • Velocity measurement     │     │  │  │  │  │  │                │
│ • Event FIFO               │     │  │  │  │  │  │                │
│ • Debounce logic           │     │  │  │  │  │  │                │
└────────────────┬───────────┘     │  │  │  │  │  │                │
                 │                 │  │  │  │  │  │                │
                 │ Note Events     │  │  │  │  │  │                │
                 │                 │  │  │  │  │  │                │
            ┌────▼────────────┐    │  │  │  │  │  │                │
            │  VOICE MANAGER  │    │  │  │  │  │  │                │
            │  (Custom RTL)   │    │  │  │  │  │  │                │
            │                 │    │  │  │  │  │  │                │
            │ • 8 voice alloc │    │  │  │  │  │  │                │
            │ • Note-on/off   │    │  │  │  │  │  │                │
            │ • Priority      │    │  │  │  │  │  │                │
            └────┬────────────┘    │  │  │  │  │  │                │
                 │ Voice Params    │  │  │  │  │  │                │
                 │                 │  │  │  │  │  │                │
       ┌─────────▼──────────┐      │  │  │  │  │  │                │
       │   WAVETABLE        │      │  │  │  │  │  │                │
       │   SYNTHESIZER      │      │  │  │  │  │  │                │
       │   (8 Voices)       │◄─────┼──┘  │  │  │  │                │
       │   (Custom RTL)     │      │     │  │  │  │                │
       │                    │      │     │  │  │  │                │
       │ • Phase accum ×8   │   ┌──▼──┐  │  │  │  │                │
       │ • Wavetable read   │   │SRAM │  │  │  │  │                │
       │ • Interpolation    │   │ 4KB │  │  │  │  │                │
       └────┬───────────────┘   └─────┘  │  │  │  │                │
            │ Voice[7:0]                  │  │  │  │                │
            │                             │  │  │  │                │
       ┌────▼────────────┐                │  │  │  │                │
       │  ADSR ENVELOPE  │                │  │  │  │                │
       │  GENERATOR ×8   │                │  │  │  │                │
       │  (Custom RTL)   │                │  │  │  │                │
       │                 │                │  │  │  │                │
       │ • Attack/Decay  │                │  │  │  │                │
       │ • Sustain/Rel   │                │  │  │  │                │
       │ • Per-voice FSM │                │  │  │  │                │
       └────┬────────────┘                │  │  │  │                │
            │ Shaped[7:0]                 │  │  │  │                │
            │                             │  │  │  │                │
       ┌────▼────────────┐                │  │  │  │                │
       │  THEREMIN       │◄───────────────┘  │  │  │                │
       │  CONTROLLER     │                   │  │  │                │
       │  (Custom RTL)   │◄──────────────────┘  │  │                │
       │                 │   SPI Master         │  │                │
       │ • ADC interface │   (CF_SPI)           │  │                │
       │ • Pitch mod     │                      │  │                │
       │ • Volume mod    │                      │  │                │
       │ • Smoothing     │                      │  │                │
       └────┬────────────┘                      │  │                │
            │ Modulation                        │  │                │
            │                                   │  │                │
       ┌────▼────────────┐                      │  │                │
       │   AUDIO MIXER   │                      │  │                │
       │   (Custom RTL)  │                      │  │                │
       │                 │                      │  │                │
       │ • 8-input sum   │                      │  │                │
       │ • Saturation    │                      │  │                │
       │ • Gain control  │                      │  │                │
       │ • L/R stereo    │                      │  │                │
       └────┬────────────┘                      │  │                │
            │ Audio L/R                         │  │                │
            │                                   │  │                │
       ┌────▼────────────┐                      │  │                │
       │   I2S OUTPUT    │◄─────────────────────┘  │                │
       │   (EF_I2S)      │                         │                │
       │                 │      I2S Controller     │                │
       │ • 48 kHz        │      (EF_I2S)           │                │
       │ • 16-bit stereo │                         │                │
       │ • FIFO buffer   │◄────────────────────────┘                │
       └────┬────────────┘      Wishbone Config                     │
            │                                                        │
            ▼                                                        │
      I2S Pads ──────────────────────────────────────────────────────┤
      (SCLK, WS, SD)                                                 │
                                                                     │
      Keyboard Pads (13 GPIO) ───────────────────────────────────────┤
      SPI Pads (4 GPIO) ─────────────────────────────────────────────┤
      Status LEDs (2 GPIO) ──────────────────────────────────────────┘
                                                                     
      Total IO: ~22 pads out of 38 available
```

## Component Descriptions

### 1. Wishbone Bus Splitter
- **Function:** Routes Wishbone transactions to appropriate peripherals
- **Configuration:** 10 peripheral slots (non-power-of-2 for error detection)
- **Address Decode:** Uses `wbs_adr_i[19:16]` for peripheral selection
- **Features:** Automatic error response for invalid addresses

### 2. GPIO Controllers (EF_GPIO8 ×2)
- **Instance 0:** Keyboard rows (6 outputs) + 2 spare
- **Instance 1:** Keyboard columns (7 inputs with pull-ups) + 1 spare
- **Features:** Interrupt on column changes for efficient key detection

### 3. Keyboard Scanner
- **Function:** Scan key matrix and generate note events
- **Inputs:** 6 row control, 7 column sense
- **Outputs:** Note-on/note-off events with velocity
- **Algorithm:**
  - Sequential row scanning at ~1 kHz rate
  - Velocity measurement: time from first touch to full press
  - Hardware debouncing with configurable delay
  - Event FIFO depth: 16 events

### 4. Voice Manager
- **Function:** Allocate notes to available voices
- **Algorithm:** Least-recently-used (LRU) voice stealing
- **Features:**
  - 8 voice slots with age tracking
  - Priority: held notes > new notes > stealing candidates
  - Configurable voice stealing policy
  - Note-on/note-off queueing

### 5. Wavetable Synthesizer (8 Voices)
- **Function:** Generate audio waveforms from SRAM tables
- **Per-Voice Components:**
  - 32-bit phase accumulator
  - 24-bit frequency control word
  - Wavetable base address register
  - Linear interpolation for smooth transitions
- **SRAM Interface:** Round-robin arbiter for 8 voices
- **Output:** 16-bit signed samples per voice

### 6. ADSR Envelope Generator (×8)
- **Function:** Shape amplitude over time for each voice
- **States:** Attack → Decay → Sustain → Release
- **Parameters (per voice):**
  - Attack rate (16-bit)
  - Decay rate (16-bit)
  - Sustain level (16-bit)
  - Release rate (16-bit)
- **Implementation:** Linear segments (configurable curves)
- **Output:** 16-bit amplitude multiplier

### 7. Theremin Controller
- **Function:** Interface external ADC and generate modulation
- **Hardware Interface:** SPI master to 12/16-bit ADC
- **Processing:**
  - Dual ADC channels: pitch (antenna 1), volume (antenna 2)
  - Moving average filter (8 samples)
  - Range mapping and scaling
  - Modulation depth control
  - two antennas with two frequencies / 
- **Output:** Pitch offset, volume scale

### 8. Audio Mixer
- **Function:** Combine all voices into stereo output
- **Algorithm:**
  - Saturating 8-input adder tree
  - Programmable per-voice pan (L/R balance)
  - Master volume control
  - Soft clipping for overdrive protection
- **Output:** 16-bit stereo (L/R channels)

### 9. I2S Output (EF_I2S)
- **Function:** Stream audio to external DAC
- **Configuration:**
  - Sample rate: 48 kHz
  - Bit depth: 16-bit
  - Channels: 2 (stereo)
  - Format: I2S standard (MSB first)
- **Features:** FIFO buffering, underrun detection

### 10. Interrupt Controller (WB_PIC)
- **Function:** Manage system interrupts
- **Sources:**
  - IRQ0: Keyboard event ready
  - IRQ1: Audio buffer underrun
  - IRQ2: Theremin data ready
  - IRQ3-15: Reserved
- **Configuration:** Priority encoding, maskable per-IRQ

---

## Wishbone Address Map

**Base Address:** `0x3000_0000` (Caravel user project area)

| **Peripheral** | **Addr Offset** | **Full Address** | **Size** | **Description** |
|----------------|-----------------|------------------|----------|-----------------|
| GPIO_0         | 0x0000          | 0x3000_0000      | 64KB     | EF_GPIO8 instance 0 (keyboard rows) |
| GPIO_1         | 0x10000         | 0x3001_0000      | 64KB     | EF_GPIO8 instance 1 (keyboard cols) |
| Keyboard Scanner | 0x20000       | 0x3002_0000      | 64KB     | Custom keyboard controller |
| Voice Manager  | 0x30000         | 0x3003_0000      | 64KB     | Voice allocation control |
| Synthesizer    | 0x40000         | 0x3004_0000      | 64KB     | Wavetable synth config (8 voices) |
| ADSR Control   | 0x50000         | 0x3005_0000      | 64KB     | ADSR parameters (8 voices) |
| Theremin Ctrl  | 0x60000         | 0x3006_0000      | 64KB     | Theremin controller + SPI |
| Audio Mixer    | 0x70000         | 0x3007_0000      | 64KB     | Mixer config & volume |
| I2S Controller | 0x80000         | 0x3008_0000      | 64KB     | EF_I2S configuration |
| WB_PIC         | 0x90000         | 0x3009_0000      | 64KB     | Interrupt controller |
| SRAM           | 0xA0000         | 0x300A_0000      | 64KB     | 4KB SRAM (wavetables) |
| *Reserved*     | 0xB0000-0xF0000 | 0x300B_0000+     | -        | Future expansion |

**Address Decode:**
- Bits [31:20]: Must be `0x300` (Caravel user area)
- Bits [19:16]: Peripheral select (0-10)
- Bits [15:0]: Internal register offset within peripheral

---

## Clocking Strategy

### Single Clock Domain Design
- **Master Clock:** `wb_clk_i` from Caravel (25-50 MHz typical)
- **Rationale:** Simplified timing, no CDC complexity
- **Sample Rate Generation:** Clock divider from master clock
  - Example: 48 MHz ÷ 1000 = 48 kHz sample rate

### Sample Clock Generation
```
Sample Clock (48 kHz) = wb_clk_i / CLOCK_DIVIDER
CLOCK_DIVIDER = wb_clk_i / 48000

For wb_clk_i = 48 MHz: CLOCK_DIVIDER = 1000
For wb_clk_i = 50 MHz: CLOCK_DIVIDER = 1042 (47.97 kHz)
```

**Clock Distribution:**
- All modules synchronous to `wb_clk_i`
- Sample-rate enable signal distributed to audio path
- Synthesizer, ADSR, mixer operate at sample rate
- Keyboard scanner at ~1 kHz (lower rate enable)

---

## Reset Strategy

- **Reset Source:** `wb_rst_i` from Caravel (active high, synchronous)
- **Reset Distribution:** Direct connection to all modules
- **Reset Sequence:**
  1. All FIFOs cleared
  2. All voices silenced
  3. GPIO set to safe defaults
  4. Registers reset to default values
  5. Interrupt controller cleared

---

## Interrupt Architecture

### IRQ Mapping to Caravel
- **Output:** `user_irq[2:0]` (3 interrupts to management SoC)
- **WB_PIC Output:** Single consolidated IRQ to `user_irq[0]`
- **Reserved:** `user_irq[2:1]` for future use

### Interrupt Flow
```
Peripheral IRQ Sources → WB_PIC → Priority Encode → user_irq[0]
                         (16 sources)  (Masked)
```

### ISR Responsibilities
1. Read WB_PIC status register to identify source
2. Service keyboard events: read event FIFO
3. Service audio underrun: refill I2S FIFO
4. Service theremin: read new ADC values
5. Clear interrupt flags (W1C)

---

## Data Flow Diagrams

### Audio Synthesis Path (Per Sample @ 48 kHz)
```
1. Sample Clock Tick
   ↓
2. Wavetable Synthesizer (8 voices parallel)
   - Phase accumulate: phase += frequency
   - SRAM read: address = (phase >> 16) + base
   - Interpolate: output = lerp(sample[n], sample[n+1], phase_frac)
   ↓
3. ADSR Envelope (8 parallel)
   - State machine update (A→D→S→R)
   - Amplitude calculation
   - Multiply: voice_out = synth_out × envelope
   ↓
4. Audio Mixer
   - Sum all 8 voices: mix = Σ(voice_out[i] × pan[i])
   - Apply master volume: out = mix × volume
   - Saturate: out = clamp(out, -32768, 32767)
   ↓
5. I2S Output
   - Write to FIFO: {left_channel, right_channel}
   - Hardware serializes to I2S pads
```

### Keyboard Event Path
```
1. Key Press (mechanical)
   ↓
2. Matrix Scanner (polling at 1 kHz)
   - Scan row[i], read columns
   - Detect change
   ↓
3. Velocity Measurement
   - Start timer on initial contact
   - Stop timer on full press
   - Calculate velocity = f(time)
   ↓
4. Event Generation
   - Create event: {note_number, velocity, note_on}
   - Push to FIFO
   - Trigger interrupt (IRQ0)
   ↓
5. Voice Manager (firmware/hardware)
   - Read event from FIFO
   - Allocate voice (LRU)
   - Configure synth voice: frequency, ADSR gate
```

### Theremin Control Path
```
1. Sample Timer (100-1000 Hz)
   ↓
2. SPI Transaction to ADC
   - Read channel 0 (pitch antenna)
   - Read channel 1 (volume antenna)
   ↓
3. Smoothing Filter
   - Moving average (8 samples)
   ↓
4. Parameter Mapping
   - Pitch: distance → frequency offset
   - Volume: distance → amplitude scale
   ↓
5. Apply to Voices
   - Pitch: add offset to all active voice frequencies
   - Volume: multiply all voice amplitudes
```

---

## Performance Analysis

### Timing Budget (48 kHz sample rate, 50 MHz clock)
- **Cycles per sample:** 50,000,000 / 48,000 ≈ 1042 cycles
- **Per-voice budget:** 1042 / 8 ≈ 130 cycles

### Per-Voice Operations (Estimate)
- Phase accumulation: 2 cycles
- SRAM read: 1-2 cycles
- Interpolation: 5-10 cycles
- ADSR calculation: 10-15 cycles
- Envelope multiply: 3-5 cycles
- **Total per voice:** ~25-35 cycles

### Mixer Operations
- 8-input addition: 8-15 cycles (tree structure)
- Saturation: 2-3 cycles
- Volume multiply: 3-5 cycles
- **Total mixer:** ~15-25 cycles

### Total Audio Path
- **Worst case:** 8×35 + 25 = **305 cycles**
- **Available:** 1042 cycles
- **Margin:** 737 cycles (71% spare for optimization)

**Conclusion:** Timing is comfortable even at 48 kHz sample rate.

---

## Resource Estimation

### SRAM Usage (4KB total)
- **Wavetable 1:** 256 samples × 4 bytes = 1024 bytes
- **Wavetable 2:** 256 samples × 4 bytes = 1024 bytes
- **Wavetable 3:** 256 samples × 4 bytes = 1024 bytes
- **Configuration/Presets:** 1024 bytes
- **Total:** 4096 bytes (100% utilization)

### Register Count Estimate
- Wavetable synthesizer: 8 voices × 5 regs = 40 regs
- ADSR generators: 8 voices × 5 regs = 40 regs
- Voice manager: ~20 regs
- Keyboard scanner: ~10 regs
- Mixer: ~15 regs
- **Total:** ~125 registers (32-bit each)

### Gate Count Estimate (Approximate)
- Custom RTL: ~3400 lines → ~15-20k gates
- EF_GPIO8 (×2): ~2k gates each = 4k gates
- CF_SRAM_1024x32: ~8k gates (hard macro)
- EF_I2S: ~5k gates
- CF_SPI: ~3k gates
- WB_PIC: ~2k gates
- **Total:** ~37-45k gates (well within Caravel limits)

---

## Power Considerations

### Dynamic Power Reduction
- **Clock gating:** Not implemented (avoid complexity)
- **Data gating:** Use enables to freeze idle voices
- **Operand isolation:** Gate arithmetic when voices inactive

### Voice Shutdown
- Inactive voices (no note assigned):
  - Disable phase accumulator
  - Gate SRAM reads
  - Bypass ADSR calculation
- **Power savings:** ~60-70% when < 4 voices active

---

## Next Steps

1. ✅ Architecture defined
2. → Link IP cores using ipm_linker
3. → Begin custom RTL development (keyboard scanner)
4. → Develop synthesizer core modules
5. → Integration and Wishbone interconnect
6. → Verification and testing

---

*Document Version: 1.0*  
*Last Updated: 2026-02-04*

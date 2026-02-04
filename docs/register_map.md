# Register Map - Digital Musical Instrument

## Address Map Summary

Base address: **0x3000_0000** (Caravel user project area)

| **Peripheral** | **Base Address** | **Size** | **Description** |
|----------------|------------------|----------|-----------------|
| GPIO_0         | 0x3000_0000      | 64KB     | EF_GPIO8 instance 0 (keyboard rows) |
| GPIO_1         | 0x3001_0000      | 64KB     | EF_GPIO8 instance 1 (keyboard cols) |
| Keyboard Scanner | 0x3002_0000    | 64KB     | Custom keyboard controller |
| Voice Manager  | 0x3003_0000      | 64KB     | Voice allocation control |
| Synthesizer    | 0x3004_0000      | 64KB     | Wavetable synth config (8 voices) |
| ADSR Control   | 0x3005_0000      | 64KB     | ADSR parameters (8 voices) |
| Theremin Ctrl  | 0x3006_0000      | 64KB     | Theremin controller |
| Audio Mixer    | 0x3007_0000      | 64KB     | Mixer config & volume |
| I2S Controller | 0x3008_0000      | 64KB     | EF_I2S configuration |
| WB_PIC         | 0x3009_0000      | 64KB     | Interrupt controller |
| SRAM           | 0x300A_0000      | 4KB      | Wavetable storage |

---

## GPIO_0 Registers (0x3000_0000)
**IP Core:** EF_GPIO8 (See EF_GPIO8 documentation for detailed registers)

### Common GPIO Registers
| **Offset** | **Name** | **Reset** | **Description** |
|------------|----------|-----------|-----------------|
| 0x00 | DATAIN | 0x00 | GPIO input data register (RO) |
| 0x04 | DATAOUT | 0x00 | GPIO output data register (RW) |
| 0x08 | DIR | 0x00 | Direction control (0=input, 1=output) (RW) |
| 0x0C | IM | 0x00 | Interrupt mask (RW) |
| 0x10 | IC | 0x00 | Interrupt clear (W1C) |
| 0x14 | MIS | 0x00 | Masked interrupt status (RO) |

---

## GPIO_1 Registers (0x3001_0000)
**IP Core:** EF_GPIO8 (Same structure as GPIO_0)

---

## Keyboard Scanner Registers (0x3002_0000)

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| 0x00 | CTRL | [31:0] | RW | 0x00000001 | Control register |
| | | [0] | RW | 1 | Enable (1=enabled, 0=disabled) |
| | | [1] | RW | 0 | Scan mode (0=continuous, 1=single) |
| | | [7:4] | RW | 0x5 | Debounce time (×10ms) |
| | | [15:8] | RW | 0x00 | Scan rate divider |
| 0x04 | STATUS | [31:0] | RO | 0x00000000 | Status register |
| | | [0] | RO | 0 | Scanning active |
| | | [1] | RO | 0 | FIFO not empty |
| | | [2] | RO | 0 | FIFO full |
| | | [3] | RO | 0 | FIFO overflow flag (W1C) |
| | | [11:8] | RO | 0 | FIFO count (0-16) |
| 0x08 | EVENT | [31:0] | RO | 0x00000000 | Event FIFO read port |
| | | [7:0] | RO | 0 | Note number (0-36) |
| | | [15:8] | RO | 0 | Velocity (0-127) |
| | | [16] | RO | 0 | Note on/off (1=on, 0=off) |
| | | [31:24] | RO | 0 | Timestamp (lower 8 bits) |
| 0x0C | IRQ_EN | [31:0] | RW | 0x00000001 | Interrupt enable |
| | | [0] | RW | 1 | Event ready interrupt enable |
| | | [1] | RW | 0 | FIFO overflow interrupt enable |
| 0x10 | IRQ_STATUS | [31:0] | W1C | 0x00000000 | Interrupt status (write 1 to clear) |
| | | [0] | W1C | 0 | Event ready |
| | | [1] | W1C | 0 | FIFO overflow |
| 0x14 | SCAN_MAP | [31:0] | RO | 0x00000000 | Current scan state (debug) |
| | | [5:0] | RO | 0 | Current row |
| | | [13:8] | RO | 0 | Column state (7 bits) |

---

## Voice Manager Registers (0x3003_0000)

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| 0x00 | CTRL | [31:0] | RW | 0x00000001 | Control register |
| | | [0] | RW | 1 | Enable voice allocation |
| | | [3:1] | RW | 0 | Voice stealing policy (0=LRU, 1=oldest, 2=quietest) |
| 0x04 | STATUS | [31:0] | RO | 0x00000000 | Status register |
| | | [7:0] | RO | 0 | Active voice mask (bit per voice) |
| | | [11:8] | RO | 0 | Active voice count (0-8) |
| 0x08 | VOICE_ALLOC[0] | [31:0] | RW | 0x00000000 | Voice 0 allocation |
| | | [7:0] | RW | 0 | Assigned note number (0-127) |
| | | [15:8] | RW | 0 | Velocity (0-127) |
| | | [16] | RW | 0 | Active (1=active, 0=free) |
| | | [17] | RW | 0 | Gate (1=held, 0=released) |
| 0x0C | VOICE_ALLOC[1] | [31:0] | RW | 0x00000000 | Voice 1 allocation (same structure) |
| 0x10 | VOICE_ALLOC[2] | [31:0] | RW | 0x00000000 | Voice 2 allocation |
| 0x14 | VOICE_ALLOC[3] | [31:0] | RW | 0x00000000 | Voice 3 allocation |
| 0x18 | VOICE_ALLOC[4] | [31:0] | RW | 0x00000000 | Voice 4 allocation |
| 0x1C | VOICE_ALLOC[5] | [31:0] | RW | 0x00000000 | Voice 5 allocation |
| 0x20 | VOICE_ALLOC[6] | [31:0] | RW | 0x00000000 | Voice 6 allocation |
| 0x24 | VOICE_ALLOC[7] | [31:0] | RW | 0x00000000 | Voice 7 allocation |

---

## Synthesizer Registers (0x3004_0000)

### Global Configuration
| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| 0x00 | CTRL | [31:0] | RW | 0x00000001 | Synthesizer control |
| | | [0] | RW | 1 | Enable synthesizer |
| | | [1] | RW | 0 | Output mute |
| | | [9:2] | RW | 0 | Sample rate divider (MSB) |
| 0x04 | CLK_DIV | [31:0] | RW | 0x000003E8 | Sample clock divider (1000 for 48kHz @ 48MHz) |

### Per-Voice Configuration (Voice 0: 0x08-0x14, Voice 1: 0x18-0x24, etc.)
**Voice N Base Offset:** `0x08 + (N × 0x10)`

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| +0x00 | VOICE_CTRL | [31:0] | RW | 0x00000000 | Voice control |
| | | [0] | RW | 0 | Voice enable |
| | | [1] | RW | 0 | Voice mute |
| +0x04 | FREQ | [31:0] | RW | 0x00000000 | Frequency control word (24-bit fixed point) |
| | | [23:0] | RW | 0 | Frequency (phase increment) |
| +0x08 | PHASE | [31:0] | RW | 0x00000000 | Phase accumulator (for sync/effects) |
| | | [31:0] | RW | 0 | Current phase value |
| +0x0C | WAVETABLE | [31:0] | RW | 0x00000000 | Wavetable configuration |
| | | [11:0] | RW | 0 | Base address in SRAM (word address) |
| | | [19:12] | RW | 0 | Wavetable length (samples, power of 2) |

**Note:** Voice registers repeat for all 8 voices.

---

## ADSR Registers (0x3005_0000)

### Per-Voice ADSR (Voice N Base: 0x00 + N × 0x10)

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| +0x00 | ATTACK | [31:0] | RW | 0x00001000 | Attack rate |
| | | [15:0] | RW | 0x1000 | Attack increment per sample |
| +0x04 | DECAY | [31:0] | RW | 0x00000800 | Decay rate |
| | | [15:0] | RW | 0x0800 | Decay decrement per sample |
| +0x08 | SUSTAIN | [31:0] | RW | 0x0000C000 | Sustain level |
| | | [15:0] | RW | 0xC000 | Sustain level (0x0000-0xFFFF) |
| +0x0C | RELEASE | [31:0] | RW | 0x00000400 | Release rate |
| | | [15:0] | RW | 0x0400 | Release decrement per sample |

**ADSR Calculation:**
- Attack: envelope += ATTACK until >= 0xFFFF
- Decay: envelope -= DECAY until <= SUSTAIN
- Sustain: envelope = SUSTAIN while gate held
- Release: envelope -= RELEASE until 0

---

## Theremin Controller Registers (0x3006_0000)

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| 0x00 | CTRL | [31:0] | RW | 0x00000001 | Control register |
| | | [0] | RW | 1 | Enable theremin controller |
| | | [1] | RW | 0 | Auto-sample mode (continuous) |
| | | [15:8] | RW | 0x0A | Sample rate divider (÷N from audio rate) |
| 0x04 | STATUS | [31:0] | RO | 0x00000000 | Status register |
| | | [0] | RO | 0 | ADC busy |
| | | [1] | RO | 0 | Data ready |
| 0x08 | PITCH_RAW | [31:0] | RO | 0x00000000 | Raw pitch ADC value |
| | | [15:0] | RO | 0 | ADC reading (12/16-bit) |
| 0x0C | VOLUME_RAW | [31:0] | RO | 0x00000000 | Raw volume ADC value |
| | | [15:0] | RO | 0 | ADC reading (12/16-bit) |
| 0x10 | PITCH_MOD | [31:0] | RO | 0x00000000 | Processed pitch modulation |
| | | [15:0] | RO | 0 | Frequency offset (signed) |
| 0x14 | VOLUME_MOD | [31:0] | RO | 0x00000000 | Processed volume modulation |
| | | [15:0] | RO | 0 | Amplitude scale (0x0000-0xFFFF) |
| 0x18 | PITCH_SCALE | [31:0] | RW | 0x00000100 | Pitch sensitivity scaling |
| | | [15:0] | RW | 0x0100 | Scale factor (8.8 fixed point) |
| 0x1C | VOLUME_SCALE | [31:0] | RW | 0x00000100 | Volume sensitivity scaling |
| | | [15:0] | RW | 0x0100 | Scale factor (8.8 fixed point) |
| 0x20 | FILTER_DEPTH | [31:0] | RW | 0x00000008 | Smoothing filter depth |
| | | [3:0] | RW | 8 | Moving average depth (2-16) |

---

## Audio Mixer Registers (0x3007_0000)

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| 0x00 | CTRL | [31:0] | RW | 0x00000001 | Mixer control |
| | | [0] | RW | 1 | Mixer enable |
| | | [1] | RW | 0 | Master mute |
| 0x04 | MASTER_VOL | [31:0] | RW | 0x00008000 | Master volume |
| | | [15:0] | RW | 0x8000 | Volume (0x0000=mute, 0xFFFF=max) |
| 0x08 | PAN[0] | [31:0] | RW | 0x00008000 | Voice 0 pan |
| | | [15:0] | RW | 0x8000 | Pan (0x0000=left, 0x8000=center, 0xFFFF=right) |
| 0x0C | PAN[1] | [31:0] | RW | 0x00008000 | Voice 1 pan |
| 0x10 | PAN[2] | [31:0] | RW | 0x00008000 | Voice 2 pan |
| 0x14 | PAN[3] | [31:0] | RW | 0x00008000 | Voice 3 pan |
| 0x18 | PAN[4] | [31:0] | RW | 0x00008000 | Voice 4 pan |
| 0x1C | PAN[5] | [31:0] | RW | 0x00008000 | Voice 5 pan |
| 0x20 | PAN[6] | [31:0] | RW | 0x00008000 | Voice 6 pan |
| 0x24 | PAN[7] | [31:0] | RW | 0x00008000 | Voice 7 pan |
| 0x28 | CLIP_MODE | [31:0] | RW | 0x00000001 | Clipping behavior |
| | | [1:0] | RW | 1 | Mode (0=hard, 1=soft, 2=none) |

---

## I2S Controller Registers (0x3008_0000)
**IP Core:** EF_I2S (See EF_I2S documentation for detailed registers)

### Key Configuration Registers
| **Offset** | **Name** | **Description** |
|------------|----------|-----------------|
| 0x00 | CTRL | Control register (enable, format, etc.) |
| 0x04 | CLK_DIV | Clock divider for sample rate |
| 0x08 | FIFO_CTRL | FIFO control and thresholds |
| 0x0C | STATUS | FIFO status and error flags |
| 0x10 | DATA_L | Left channel data write port |
| 0x14 | DATA_R | Right channel data write port |

---

## WB_PIC Registers (0x3009_0000)

| **Offset** | **Name** | **Bits** | **Type** | **Reset** | **Description** |
|------------|----------|----------|----------|-----------|-----------------|
| 0x00 | CTRL | [31:0] | RW | 0x00000001 | Global control |
| | | [0] | RW | 1 | Global interrupt enable |
| 0x04 | STATUS | [31:0] | RO | 0x00000000 | Interrupt status |
| | | [15:0] | RO | 0 | IRQ pending (one bit per source) |
| 0x08 | MASK | [31:0] | RW | 0x00000007 | Interrupt mask (1=enabled) |
| | | [15:0] | RW | 0x07 | Per-IRQ enable mask |
| 0x0C | CLEAR | [31:0] | W1C | 0x00000000 | Interrupt clear (write 1 to clear) |
| | | [15:0] | W1C | 0 | Per-IRQ clear |
| 0x10 | PRIORITY[0] | [31:0] | RW | 0x00000000 | IRQ priority configuration (4 IRQs per reg) |
| 0x14 | PRIORITY[1] | [31:0] | RW | 0x00000000 | IRQ 4-7 priority |
| 0x18 | PRIORITY[2] | [31:0] | RW | 0x00000000 | IRQ 8-11 priority |
| 0x1C | PRIORITY[3] | [31:0] | RW | 0x00000000 | IRQ 12-15 priority |
| 0x20 | TRIG_MODE | [31:0] | RW | 0x00000000 | Trigger mode (0=level, 1=edge) |
| | | [15:0] | RW | 0 | Per-IRQ trigger mode |

### IRQ Source Mapping
- **IRQ0:** Keyboard event ready
- **IRQ1:** Audio buffer underrun
- **IRQ2:** Theremin data ready
- **IRQ3-15:** Reserved for future use

---

## SRAM (0x300A_0000)

**Type:** CF_SRAM_1024x32  
**Size:** 4KB (1024 words × 32 bits)  
**Access:** Direct Wishbone memory-mapped access

| **Address Range** | **Usage** | **Size** |
|-------------------|-----------|----------|
| 0x300A_0000 - 0x300A_03FF | Wavetable 1 | 1KB (256 samples × 4 bytes) |
| 0x300A_0400 - 0x300A_07FF | Wavetable 2 | 1KB |
| 0x300A_0800 - 0x300A_0BFF | Wavetable 3 | 1KB |
| 0x300A_0C00 - 0x300A_0FFF | Configuration/Presets | 1KB |

---

## Programming Notes

### Initialization Sequence
1. Configure system clock divider (SYNTHESIZER.CLK_DIV)
2. Load wavetables into SRAM
3. Configure ADSR parameters for all voices
4. Set up mixer pan positions and master volume
5. Enable GPIO interrupts for keyboard
6. Configure I2S for 48kHz stereo output
7. Enable keyboard scanner
8. Enable voice manager
9. Enable synthesizer
10. Enable mixer and I2S output

### Typical Operation Flow
1. **Keyboard event interrupt:**
   - Read KEYBOARD_SCANNER.EVENT
   - Parse note number, velocity, on/off
   - Update VOICE_MANAGER voice allocation
   - Trigger ADSR gate
2. **Audio synthesis (automatic):**
   - Hardware generates samples at 48 kHz
   - Voices computed in parallel
   - Mixed and sent to I2S FIFO
3. **Theremin control (periodic):**
   - Read THEREMIN.PITCH_MOD and VOLUME_MOD
   - Apply modulation to voice frequencies/amplitudes

### Register Access Patterns
- **Setup:** One-time writes to configuration registers
- **Realtime:** Reads from status/FIFO registers, writes to voice control
- **Interrupt:** Read-modify-clear operations on interrupt status registers

---

*Document Version: 1.0*  
*Last Updated: 2026-02-04*

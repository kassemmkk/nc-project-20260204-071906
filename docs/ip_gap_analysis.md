# IP Gap Analysis - Digital Musical Instrument

## Executive Summary

This document analyzes the available IP cores in the NativeChips library and identifies gaps for the digital musical instrument design. The analysis covers keyboard interface, audio synthesis, theremin control, and audio output subsystems.

## Available IP Inventory

### 1. EF_GPIO8 - 8-bit GPIO Controller ✓
**Version:** v1.1.0  
**Status:** NativeChips Verified IP  
**Capabilities:**
- 8 bidirectional GPIO pins
- Configurable input/output direction per pin
- Interrupt support on pin changes
- Wishbone interface

**Usage in This Project:**
- Primary: Keyboard matrix scanning (6x7 matrix for 37 keys requires 13 GPIOs)
- Secondary: Control signals and status indicators
- **Gap:** Need 2 instances of EF_GPIO8 (16 pins total) for keyboard matrix

### 2. CF_SRAM_1024x32 - 4KB SRAM with Wishbone ✓
**Version:** v1.2.0  
**Status:** NativeChips Verified IP  
**Capabilities:**
- 1024 words × 32 bits = 4KB total
- Wishbone interface (hard macro)
- Single-cycle read/write access
- Direct Wishbone bus connection

**Usage in This Project:**
- Wavetable storage for synthesis engine
- Preset/configuration storage
- **Allocation:**
  - Wavetable data: 3KB (768 samples × 4 bytes for up to 3 waveforms)
  - Configuration/presets: 1KB
- **Status:** Sufficient for basic wavetable synthesis

### 3. EF_I2S - I2S Audio Interface ✓
**Version:** v1.2.0  
**Status:** Available (not in verified list, but in IP library)  
**Capabilities:**
- I2S digital audio output
- Configurable sample rates
- 16/24/32-bit audio support
- FIFO buffering
- Wishbone interface

**Usage in This Project:**
- Primary audio output interface
- Target: 48 kHz, 16-bit stereo
- **Status:** Perfect fit, requires integration and configuration

### 4. CF_SPI - SPI Controller ✓
**Version:** v2.0.1  
**Status:** NativeChips Verified IP  
**Capabilities:**
- SPI master/slave modes
- Configurable clock polarity and phase
- Hardware chip select management
- FIFO support
- Wishbone interface

**Usage in This Project:**
- Interface to external ADC for theremin control
- Target: 12-bit or 16-bit ADC (e.g., MCP3202, ADS7883)
- **Status:** Suitable for theremin sensor interfacing

### 5. CF_TMR32 - 32-bit Timer with PWM ✓
**Version:** v1.1.0  
**Status:** NativeChips Verified IP  
**Capabilities:**
- 32-bit timer/counter
- PWM generation capability
- Multiple compare channels
- Interrupt support
- Wishbone interface

**Usage in This Project:**
- Potential alternative for simple audio output (PWM DAC)
- Timing reference for keyboard velocity sensing
- **Status:** Backup option; I2S is preferred for audio quality

### 6. WB_PIC - Programmable Interrupt Controller ✓
**Status:** Available in template  
**Capabilities:**
- 16 interrupt sources (IRQ0-IRQ15)
- 4-level programmable priority
- Per-IRQ enable masks + global enable
- Edge/level triggering modes
- Wishbone interface

**Usage in This Project:**
- Keyboard press interrupts
- Audio buffer underrun interrupts
- Theremin data ready interrupts
- **Status:** Essential for efficient CPU interaction

---

## Functional Gap Analysis

### Gap #1: Wavetable Synthesizer Core ❌
**Function:** Multi-voice polyphonic wavetable synthesis engine  
**Requirements:**
- 8 independent voice channels
- Phase accumulation for frequency control
- SRAM wavetable reading with interpolation
- Per-voice pitch control
- Amplitude modulation support

**Impact:** **HIGH** - Core functionality, no available IP  
**Solution:** **Custom RTL development required**
- Implement phase accumulator (32-bit per voice)
- Wavetable reader with linear interpolation
- Voice channel architecture
- Estimated complexity: ~1000 lines of RTL

### Gap #2: ADSR Envelope Generator ❌
**Function:** Attack-Decay-Sustain-Release envelope shaping  
**Requirements:**
- 8 independent ADSR generators (one per voice)
- Programmable attack, decay, sustain, release parameters
- Linear or exponential curves
- Gate/trigger inputs from keyboard
- Real-time amplitude output

**Impact:** **HIGH** - Essential for musical expression  
**Solution:** **Custom RTL development required**
- State machine for ADSR phases
- Rate multiplier for slope control
- Per-voice parameter storage
- Estimated complexity: ~500 lines of RTL

### Gap #3: Audio Mixer and Voice Manager ❌
**Function:** Mix multiple voices and manage voice allocation  
**Requirements:**
- Sum 8 voice channels with overflow protection
- Voice allocation logic (assign notes to free voices)
- Priority management for voice stealing
- Theremin modulation application
- Digital volume/gain control

**Impact:** **HIGH** - Required for polyphony  
**Solution:** **Custom RTL development required**
- Saturating adder tree for mixing
- Voice allocation FSM
- Note-on/note-off management
- Estimated complexity: ~600 lines of RTL

### Gap #4: Keyboard Scanner with Velocity Sensing ❌
**Function:** Scan 37-key matrix and measure velocity  
**Requirements:**
- 6×7 matrix scanning (37 keys)
- Velocity capture via key press timing
- Debounce logic
- Key press/release event generation
- FIFO for event buffering

**Impact:** **MEDIUM** - Can use EF_GPIO8 with custom control logic  
**Solution:** **Custom RTL development required**
- Matrix scanner state machine
- Timer-based velocity measurement
- Event FIFO and interrupt generation
- Estimated complexity: ~400 lines of RTL

### Gap #5: Theremin Controller Interface ❌
**Function:** Interface external ADC and process theremin data  
**Requirements:**
- SPI interface to ADC (uses CF_SPI IP)
- Convert distance data to pitch/volume parameters
- Smoothing/filtering for stable control
- Real-time modulation output

**Impact:** **MEDIUM** - Can use CF_SPI with custom control wrapper  
**Solution:** **Wrapper around CF_SPI + custom processing**
- SPI transaction manager
- Data smoothing filter
- Parameter mapping logic
- Estimated complexity: ~300 lines of RTL

### Gap #6: I2S Configuration and Control ❌
**Function:** Configure and control I2S interface  
**Requirements:**
- 48 kHz sample rate configuration
- 16-bit stereo format
- Audio data streaming from mixer
- Buffer management
- Clock generation/management

**Impact:** **LOW** - EF_I2S IP provides most functionality  
**Solution:** **Configuration wrapper + glue logic**
- Wishbone configuration registers
- Sample rate clock divider
- Audio data interface adapter
- Estimated complexity: ~200 lines of RTL

---

## IP Reuse vs. Custom Development Summary

| **Component** | **IP Core** | **Custom RTL** | **Total Effort** |
|---------------|-------------|----------------|------------------|
| Keyboard GPIO | EF_GPIO8 (2×) | Scanner FSM | Medium |
| Wavetable Storage | CF_SRAM_1024x32 | Access logic | Low |
| Synthesizer Core | None | Full implementation | High |
| ADSR Envelope | None | Full implementation | High |
| Audio Mixer | None | Full implementation | Medium-High |
| Voice Manager | None | Full implementation | Medium |
| Theremin Interface | CF_SPI | Wrapper + processing | Medium |
| Audio Output | EF_I2S | Configuration wrapper | Low |
| Interrupt Controller | WB_PIC | Configuration only | Low |
| Bus Interconnect | wishbone_bus_splitter | Address decode | Low |

---

## Trade-off Analysis

### Option A: All-Custom Audio Synthesis
**Pros:**
- Full control over sound quality and features
- Optimized for specific requirements
- Can add custom effects and modulation

**Cons:**
- Significant development time (~3000 lines of RTL)
- Complex verification required
- Higher risk of bugs

**Estimated Timeline:** 2-3 weeks development + 1 week verification

### Option B: Simplified PWM-Based Audio (CF_TMR32)
**Pros:**
- Faster development using TMR32 PWM
- Simpler architecture
- Lower gate count

**Cons:**
- Limited audio quality (8-10 bit effective resolution)
- No polyphony (or limited voices)
- Requires extensive external filtering

**Estimated Timeline:** 1 week development + 3 days verification

### Option C: Hybrid Approach (Selected)
**Pros:**
- Use verified IPs where available (GPIO, SPI, I2S)
- Custom RTL only for synthesis core
- Balance of quality and development time
- I2S provides high-quality audio path

**Cons:**
- Still requires significant custom development
- I2S IP may need adaptation

**Estimated Timeline:** 1.5-2 weeks development + 1 week verification

---

## Recommended Approach: **Option C - Hybrid**

### IP Cores to Use:
1. **EF_GPIO8** (×2) - Keyboard scanning
2. **CF_SRAM_1024x32** - Wavetable storage  
3. **EF_I2S** - Audio output
4. **CF_SPI** - Theremin ADC interface
5. **WB_PIC** - Interrupt management
6. **wishbone_bus_splitter** - Bus interconnect

### Custom RTL Required:
1. **Wavetable Oscillator** (8 voices) - ~1000 LOC
2. **ADSR Envelope Generator** (8 instances) - ~500 LOC
3. **Audio Mixer & Voice Manager** - ~600 LOC
4. **Keyboard Scanner Controller** - ~400 LOC
5. **Theremin Controller Wrapper** - ~300 LOC
6. **I2S Interface Wrapper** - ~200 LOC
7. **Top-level Integration** - ~400 LOC

**Total Custom RTL:** ~3400 lines of code

---

## Integration Risks and Mitigation

### Risk #1: SRAM Bandwidth
**Issue:** 8 voices × 48 kHz = 384k samples/sec, but SRAM is shared  
**Mitigation:**
- Use round-robin arbiter for voice access
- Cache/interpolate samples to reduce accesses
- 50 MHz system clock provides ~130 cycles per sample at 48 kHz

### Risk #2: I2S Timing and Synchronization
**Issue:** I2S requires precise timing, clock domain crossing  
**Mitigation:**
- Use asynchronous FIFO between mixer and I2S
- Implement back-pressure for buffer management
- Verify clock domain crossing thoroughly

### Risk #3: Real-time Performance
**Issue:** All voices must compute within one sample period  
**Mitigation:**
- Pipeline voice processing
- Pre-compute envelope values
- Optimize critical paths

### Risk #4: Pad Count Limitations
**Issue:** Caravel has limited user IO pads (38 digital IO)  
**Allocation:**
- Keyboard matrix: 13 pads (6 rows + 7 columns)
- I2S audio: 3 pads (SCLK, WS, SD)
- SPI theremin: 4 pads (SCK, MOSI, MISO, CS)
- Status/control: 2-3 pads
- **Total:** ~22-23 pads (sufficient)

---

## Conclusion

The NativeChips IP library provides excellent coverage for peripheral interfaces (GPIO, SPI, I2S, SRAM), but the core audio synthesis functionality requires custom RTL development. This is expected and acceptable, as audio synthesis is application-specific.

The hybrid approach leveraging verified IPs for interfaces and custom RTL for the synthesis engine provides the best balance of:
- **Development time:** Moderate (2-3 weeks)
- **Sound quality:** High (16-bit I2S output)
- **Feature completeness:** Full (8 voices, ADSR, theremin)
- **Risk:** Moderate (custom audio processing)

All identified gaps have clear implementation paths, and no blocking issues have been identified.

---

*Document Version: 1.0*  
*Last Updated: 2026-02-04*

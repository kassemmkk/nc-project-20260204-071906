# Digital Musical Instrument - Caravel User Project

## Project Overview

This project implements a complete home electronic musical instrument on the Efabless Caravel platform (Sky130 ASIC). The instrument features:

- **37-key velocity-sensitive musical keyboard** (3 octaves)
- **8-voice polyphonic wavetable synthesizer** with ADSR envelope control
- **Theremin-style controller** for real-time pitch and volume modulation
- **High-quality I2S audio output** (48 kHz, 16-bit stereo)
- **Digital amplifier control** with programmable gain

## Initial User Requirements

**Original Prompt:** "design a home electronic instrument that has a musical keyboard, sound synthesis, amp, audio output and theremin control"

**Detailed Requirements from Questionnaire:**
- 37 keys (3 octaves) with velocity sensing
- Wavetable synthesis using custom tables stored in SRAM
- 8-voice polyphony
- Full ADSR envelope control (Attack, Decay, Sustain, Release)
- Theremin control for pitch and volume modulation
- Custom wavetables stored in SRAM

## Design Approach

### System Architecture
The instrument is implemented as a Caravel user project with the following major components:

1. **Keyboard Interface** - Matrix scanner with velocity sensing using GPIO
2. **Sound Synthesis Engine** - 8-voice wavetable synthesizer with SRAM-based waveform storage
3. **Theremin Controller** - SPI interface to external ADC for distance-to-control conversion
4. **Audio Output** - I2S digital audio interface for connection to external DAC
5. **Control System** - Wishbone bus interconnect with interrupt controller

### IP Reuse Strategy
- **EF_GPIO8**: Keyboard matrix scanning
- **CF_SRAM_1024x32**: 4KB SRAM for wavetable storage
- **EF_I2S**: I2S audio output interface
- **CF_SPI**: Theremin ADC interface
- **WB_PIC**: Programmable interrupt controller
- **Custom RTL**: Synthesizer core, voice manager, ADSR, mixer

## Project Status

**Current Stage:** RTL Development  
**Overall Progress:** 19% (Task 5 of 21 in progress)

### Milestones
- [x] Project Setup Complete (Tasks 1-4 ✓)
  - Caravel template copied
  - IP gap analysis complete
  - Architecture designed with full address map
  - Register map, pad map, integration notes documented
  - IPs linked: EF_GPIO8, CF_SRAM_1024x32, CF_I2S, CF_SPI
- [ ] RTL Development In Progress (Tasks 5-14)
  - Keyboard scanner module (in progress)
  - Audio synthesis modules (pending)
  - Integration modules (pending)
- [ ] Verification Pending (Tasks 15-20)
- [ ] Final Documentation Pending (Task 21)

## Repository Structure

```
├── verilog/
│   ├── rtl/                    # RTL source files
│   │   ├── user_project.v      # Top-level user project
│   │   ├── user_project_wrapper.v  # Caravel wrapper
│   │   ├── keyboard_scanner.v  # Keyboard interface
│   │   ├── wavetable_osc.v    # Wavetable oscillator
│   │   ├── adsr_envelope.v    # Envelope generator
│   │   ├── audio_mixer.v      # Voice mixer
│   │   └── ...
│   └── dv/
│       └── cocotb/            # Cocotb verification tests
├── openlane/                  # OpenLane configuration
│   ├── user_project/
│   └── user_project_wrapper/
├── docs/                      # Documentation
│   ├── register_map.md       # Register definitions
│   ├── pad_map.md            # IO pad assignments
│   └── integration_notes.md  # Integration guide
└── ip/                       # Linked IP cores
```

## Next Steps

1. Complete IP gap analysis
2. Design system architecture and Wishbone address map
3. Link required IP cores using ipm_linker
4. Develop custom RTL modules
5. Integration and verification

---

*Last Updated: 2026-02-04 - Project Initialization*
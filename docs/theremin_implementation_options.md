# Theremin Implementation Options for Digital Musical Instrument

## Overview

A theremin is a musical instrument that allows hands-free control of pitch and volume through proximity sensing. For a digital implementation on an ASIC, we need to convert physical hand position/distance into digital control signals. This document explores various implementation approaches suitable for the Caravel platform.

---

## Option 1: External ADC with Capacitive Sensing (CURRENT IMPLEMENTATION)

### Architecture
```
Antenna → Capacitive → Oscillator → Frequency-to- → ADC → SPI → ASIC
         Sensor       Circuit      Voltage
```

### Implementation Details

**External Hardware:**
- Metal antenna (10-30cm length)
- LC oscillator circuit (e.g., Colpitts oscillator)
- Frequency-to-voltage converter (e.g., LM2907, CD4046 PLL)
- 12-bit ADC (e.g., MCP3202, ADS7883)
- SPI interface to ASIC

**ASIC Interface (Already Implemented):**
- `theremin_ctrl.v` module with SPI master
- Reads 2-channel ADC (pitch + volume)
- Moving average filter (16 samples)
- Configurable sensitivity scaling
- Output: 16-bit pitch_mod, 16-bit volume_mod

**Advantages:**
- ✅ Highest sensitivity and range (30-50cm)
- ✅ True theremin-style control
- ✅ Analog precision with digital filtering
- ✅ Already implemented in current design

**Disadvantages:**
- ❌ Requires external analog circuitry
- ❌ Needs tuning and calibration
- ❌ More complex PCB design

**Cost:** ~$5-10 in external components

---

## Option 2: Ultrasonic Distance Sensors (HC-SR04)

### Architecture
```
HC-SR04 → Echo Pulse → GPIO Pulse → ASIC
         Width       Width Measure
```

### Implementation Details

**External Hardware:**
- HC-SR04 ultrasonic sensor (×2 for pitch and volume)
- 5V power supply (or 3.3V compatible variant)
- Trigger and echo GPIO connections

**ASIC Implementation:**
```verilog
module ultrasonic_theremin (
    input wire clk,
    input wire rst_n,
    
    // Pitch sensor
    output reg pitch_trigger,
    input wire pitch_echo,
    
    // Volume sensor  
    output reg volume_trigger,
    input wire volume_echo,
    
    output reg [15:0] pitch_mod,
    output reg [15:0] volume_mod
);

    // Trigger pulse generator (10µs pulse every 60ms)
    reg [15:0] trigger_counter;
    always @(posedge clk) begin
        if (trigger_counter < TRIGGER_PERIOD)
            trigger_counter <= trigger_counter + 1;
        else
            trigger_counter <= 0;
    end
    
    assign pitch_trigger = (trigger_counter < TRIGGER_WIDTH);
    
    // Echo pulse width measurement
    reg [15:0] echo_timer;
    reg echo_measuring;
    
    always @(posedge clk) begin
        if (pitch_echo && !echo_measuring) begin
            echo_measuring <= 1;
            echo_timer <= 0;
        end else if (echo_measuring) begin
            if (pitch_echo)
                echo_timer <= echo_timer + 1;
            else begin
                echo_measuring <= 0;
                // Distance = echo_timer * (clock_period * sound_speed / 2)
                pitch_mod <= echo_timer;
            end
        end
    end
endmodule
```

**Distance Calculation:**
```
Distance (cm) = (Echo_Time_µs × 0.0343) / 2
For 50 MHz clock: Distance = (Echo_Cycles × 0.02 × 0.0343) / 2
Range: 2cm to 400cm
Resolution: ~0.3cm
```

**Advantages:**
- ✅ Simple digital interface (no ADC required)
- ✅ Low cost (~$2 per sensor)
- ✅ Easy to implement with GPIO
- ✅ Good range (2-400cm)
- ✅ No calibration needed

**Disadvantages:**
- ❌ Lower update rate (~60Hz max vs. 1kHz for capacitive)
- ❌ Beam angle (~15°) limits spatial resolution
- ❌ Can be affected by ambient noise
- ❌ Less "theremin-like" feel

**Cost:** ~$2-4 (two sensors)

---

## Option 3: Time-of-Flight (ToF) Sensor via I2C

### Architecture
```
VL53L0X → I2C → ASIC
(ToF)     Interface
```

### Implementation Details

**External Hardware:**
- VL53L0X or VL53L1X ToF sensor (×2)
- I2C interface (SCL, SDA)
- 2.8V or 3.3V power

**ASIC Implementation:**
```verilog
module tof_theremin (
    input wire clk,
    input wire rst_n,
    
    // I2C interface
    output reg scl,
    inout wire sda,
    
    output reg [15:0] pitch_mod,
    output reg [15:0] volume_mod
);

    // I2C master state machine
    localparam I2C_IDLE = 0;
    localparam I2C_START = 1;
    localparam I2C_ADDR = 2;
    localparam I2C_READ = 3;
    localparam I2C_STOP = 4;
    
    reg [2:0] i2c_state;
    reg [7:0] i2c_data;
    
    // Read distance from VL53L0X
    always @(posedge clk) begin
        case (i2c_state)
            I2C_IDLE: begin
                // Poll sensor at 100Hz
                if (sample_trigger)
                    i2c_state <= I2C_START;
            end
            
            I2C_START: begin
                // Send I2C start condition
                sda_out <= 0;
                i2c_state <= I2C_ADDR;
            end
            
            I2C_ADDR: begin
                // Send device address (0x29) + read bit
                // ... I2C protocol implementation
            end
            
            I2C_READ: begin
                // Read 16-bit distance value
                pitch_mod <= {i2c_data_high, i2c_data_low};
                i2c_state <= I2C_STOP;
            end
            
            I2C_STOP: begin
                // Send I2C stop condition
                i2c_state <= I2C_IDLE;
            end
        endcase
    end
endmodule
```

**Sensor Characteristics:**
- Range: 5-200cm (VL53L0X), 5-400cm (VL53L1X)
- Resolution: 1mm
- Update rate: Up to 50Hz (continuous mode)
- Interface: I2C (400 kHz)

**Advantages:**
- ✅ Very high precision (1mm resolution)
- ✅ Fast update rate (50Hz)
- ✅ Narrow beam (25° FOV) for precise control
- ✅ I2C interface (can use CF_I2C IP if available)
- ✅ Not affected by color or texture
- ✅ Works in ambient light

**Disadvantages:**
- ❌ Limited range (max 400cm)
- ❌ Requires I2C master (need CF_I2C IP or custom)
- ❌ More expensive (~$5-8 per sensor)
- ❌ Requires firmware configuration

**Cost:** ~$10-16 (two sensors)

---

## Option 4: Infrared Proximity Sensors (Analog)

### Architecture
```
GP2Y0A → Analog → ADC → SPI → ASIC
        Voltage
```

### Implementation Details

**External Hardware:**
- Sharp GP2Y0A21YK (10-80cm range) (×2)
- 12-bit ADC (MCP3202)
- SPI interface

**Sensor Output:**
```
Voltage = k / (Distance + b)
Where k and b are calibration constants
```

**ASIC Implementation:**
- Use existing `theremin_ctrl.v` module (already implemented)
- SPI ADC interface reads analog voltage
- Firmware converts voltage to distance using lookup table

**Lookup Table (in firmware or SRAM):**
```c
const uint16_t distance_lut[256] = {
    // Voltage to distance mapping
    800,  // 0V   -> 80cm (max range)
    650,  // 0.5V -> 65cm
    400,  // 1.0V -> 40cm
    250,  // 1.5V -> 25cm
    150,  // 2.0V -> 15cm
    100,  // 2.5V -> 10cm
    // ... 256 entries
};
```

**Advantages:**
- ✅ Analog output (continuous sensing)
- ✅ Fast response (~16ms)
- ✅ Can use existing theremin_ctrl.v module
- ✅ Good range (10-80cm)
- ✅ Low cost (~$5 per sensor)

**Disadvantages:**
- ❌ Non-linear output (requires LUT)
- ❌ Affected by reflective surfaces
- ❌ Limited range compared to ultrasonic
- ❌ Requires external ADC

**Cost:** ~$12-15 (two sensors + ADC)

---

## Option 5: Fully Digital Capacitive Sensing (FDC2214)

### Architecture
```
Antenna → LC Tank → FDC2214 → I2C → ASIC
         Circuit    (Cap-to-   Interface
                    Digital)
```

### Implementation Details

**External Hardware:**
- FDC2214 capacitance-to-digital converter (Texas Instruments)
- LC resonant tank (antenna + inductor)
- I2C interface

**ASIC Implementation:**
```verilog
module fdc_theremin (
    input wire clk,
    input wire rst_n,
    
    // I2C to FDC2214
    output reg scl,
    inout wire sda,
    
    output reg [15:0] pitch_mod,
    output reg [15:0] volume_mod
);

    // I2C master to read 28-bit capacitance value
    // FDC2214 registers:
    // 0x00-0x03: Channel 0-3 data (28-bit)
    // 0x08-0x0B: Configuration
    
    reg [27:0] cap_ch0;  // Pitch antenna
    reg [27:0] cap_ch1;  // Volume antenna
    
    // Convert capacitance to modulation value
    always @(posedge clk) begin
        // Higher capacitance = closer hand
        pitch_mod <= cap_ch0[27:12];   // Use upper 16 bits
        volume_mod <= cap_ch1[27:12];
    end
endmodule
```

**FDC2214 Characteristics:**
- Resolution: 28-bit (268 million counts)
- Sample rate: Up to 13.3 kSPS per channel
- Channels: 4 (use 2 for pitch and volume)
- Interface: I2C
- Range: Depends on antenna design (typically 10-50cm)

**Advantages:**
- ✅ Highest resolution of all methods
- ✅ True capacitive sensing (like original theremin)
- ✅ Fast update rate (13 kHz)
- ✅ Digital output (no ADC needed)
- ✅ 4 channels (could add more controls)
- ✅ Very sensitive

**Disadvantages:**
- ❌ Requires I2C master implementation
- ❌ More expensive (~$3-5 per chip)
- ❌ Requires careful antenna design
- ❌ Sensitive to EMI

**Cost:** ~$5-8 (single chip for 4 channels)

---

## Option 6: Camera-Based Hand Tracking (Advanced)

### Architecture
```
Camera → Image → Blob → SPI/ → ASIC
        Sensor   Detection  Parallel
                 (MCU)      Interface
```

### Implementation Details

**External Hardware:**
- Small camera module (e.g., OV7670)
- External MCU for image processing (e.g., ESP32)
- SPI or parallel interface to ASIC

**Processing Chain:**
1. Camera captures frame (30-60 fps)
2. MCU performs blob detection (hand position)
3. Calculate X, Y coordinates
4. Send coordinates via SPI to ASIC

**ASIC Implementation:**
```verilog
module camera_theremin (
    input wire clk,
    input wire rst_n,
    
    // SPI from MCU
    input wire spi_sck,
    input wire spi_mosi,
    output reg spi_miso,
    input wire spi_cs_n,
    
    output reg [15:0] pitch_mod,   // X position
    output reg [15:0] volume_mod   // Y position
);

    // SPI slave receiver
    reg [31:0] spi_rx_data;
    
    always @(posedge spi_sck) begin
        if (!spi_cs_n) begin
            spi_rx_data <= {spi_rx_data[30:0], spi_mosi};
        end
    end
    
    // Extract X and Y from received data
    always @(negedge spi_cs_n) begin
        pitch_mod <= spi_rx_data[31:16];   // X position
        volume_mod <= spi_rx_data[15:0];   // Y position
    end
endmodule
```

**Advantages:**
- ✅ Non-contact (no physical sensors)
- ✅ Can track multiple hands
- ✅ Can add gesture recognition
- ✅ Cool factor (futuristic)
- ✅ Could add visual feedback via display

**Disadvantages:**
- ❌ Very high complexity
- ❌ Requires external MCU for processing
- ❌ High power consumption
- ❌ Latency (30-60ms)
- ❌ Lighting dependent
- ❌ Overkill for theremin application

**Cost:** ~$15-30 (camera + MCU)

---

## Option 7: Resistive/Conductive Touch Strip

### Architecture
```
Touch Strip → Resistive → ADC → SPI → ASIC
             Divider
```

### Implementation Details

**External Hardware:**
- Resistive touch strip (soft potentiometer)
- Voltage divider circuit
- ADC (MCP3202)

**Touch Strip Types:**
1. **SoftPot** (Spectra Symbol): 10-50cm linear potentiometer
2. **Flex Sensor**: Bend-sensitive resistor
3. **Conductive Fabric**: Custom DIY touch surface

**ASIC Implementation:**
- Use existing `theremin_ctrl.v` module
- ADC reads position as voltage (0-3.3V)
- Direct mapping: Voltage → Position → Pitch/Volume

**Advantages:**
- ✅ Very simple (just a resistor)
- ✅ No complex processing
- ✅ Can use existing SPI ADC interface
- ✅ Low latency
- ✅ Very reliable

**Disadvantages:**
- ❌ Requires physical touch (not true theremin)
- ❌ Limited expressive control
- ❌ Wear over time
- ❌ Not hands-free

**Cost:** ~$8-15 (touch strip + ADC)

---

## Option 8: Radar-Based Gesture Sensing (Soli/mm-Wave)

### Architecture
```
60GHz → Doppler → Signal → SPI → ASIC
Radar   Shift    Processing
```

### Implementation Details

**External Hardware:**
- Google Soli chip or similar mm-wave radar module
- Pre-processed gesture output via SPI

**Characteristics:**
- Range: 0-15cm (near field)
- Can detect micro-gestures (finger movements)
- Very high precision
- Works through materials

**Advantages:**
- ✅ Extremely high sensitivity
- ✅ Can detect finger micro-movements
- ✅ Works through objects
- ✅ Future-proof technology

**Disadvantages:**
- ❌ Very expensive (~$50-100)
- ❌ Limited availability
- ❌ Regulatory restrictions (60 GHz)
- ❌ Overkill for simple theremin

**Cost:** ~$50-100

---

## Comparison Table

| Method | Range | Resolution | Update Rate | Complexity | Cost | Theremin Feel |
|--------|-------|------------|-------------|------------|------|---------------|
| **Capacitive + ADC** ✓ | 30-50cm | 12-bit (4096) | 1-10 kHz | Medium | $5-10 | ★★★★★ Authentic |
| **Ultrasonic** | 2-400cm | 0.3cm | 60 Hz | Low | $2-4 | ★★★☆☆ Good |
| **ToF (I2C)** | 5-200cm | 1mm | 50 Hz | Medium | $10-16 | ★★★★☆ Excellent |
| **IR Proximity** | 10-80cm | 8-bit (256) | 60 Hz | Low | $12-15 | ★★★☆☆ Good |
| **FDC2214** | 10-50cm | 28-bit | 13 kHz | High | $5-8 | ★★★★★ Authentic |
| **Camera** | 0-200cm | 1-2cm | 30 Hz | Very High | $15-30 | ★★☆☆☆ Poor |
| **Touch Strip** | 10-50cm | 10-bit | 1 kHz | Very Low | $8-15 | ★☆☆☆☆ None |
| **mm-Wave Radar** | 0-15cm | <1mm | 100 Hz | Very High | $50-100 | ★★★★★ Excellent |

---

## Recommended Implementation Strategy

### For Current Design (Already Done): **Capacitive + ADC via SPI** ✓

**Why this is the best choice:**
1. ✅ **Already implemented** in `theremin_ctrl.v`
2. ✅ True theremin-style capacitive sensing
3. ✅ High sensitivity and resolution
4. ✅ Fast update rate (1-10 kHz)
5. ✅ Reasonable cost
6. ✅ Proven technology

### For Future Upgrades:

**Option A: FDC2214 (Highest Performance)**
- Best resolution (28-bit)
- True capacitive sensing
- 4 channels (add more controls)
- Requires I2C master (could add CF_I2C IP)

**Option B: VL53L0X ToF (Best Balance)**
- Excellent precision (1mm)
- Easy to interface
- I2C (standard protocol)
- Reliable and consistent

**Option C: Ultrasonic (Simplest)**
- No additional IPs needed (just GPIO)
- Very low cost
- Easy to implement
- Good enough for basic theremin

---

## Implementation Code Examples

### GPIO Pulse Width Measurement (for Ultrasonic)

```verilog
module gpio_pulse_width_measure (
    input wire clk,              // 50 MHz
    input wire rst_n,
    input wire trigger,          // Start measurement
    input wire echo,             // Pulse to measure
    output reg [15:0] width,     // Pulse width in clock cycles
    output reg valid             // Measurement valid
);

    reg measuring;
    reg [15:0] counter;
    reg echo_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            measuring <= 1'b0;
            counter <= 16'h0000;
            width <= 16'h0000;
            valid <= 1'b0;
            echo_prev <= 1'b0;
        end else begin
            echo_prev <= echo;
            
            // Detect rising edge of echo
            if (echo && !echo_prev && !measuring) begin
                measuring <= 1'b1;
                counter <= 16'h0001;
                valid <= 1'b0;
            end
            // Count while echo is high
            else if (measuring && echo) begin
                counter <= counter + 1'b1;
            end
            // Detect falling edge
            else if (measuring && !echo && echo_prev) begin
                measuring <= 1'b0;
                width <= counter;
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;
            end
        end
    end
endmodule
```

### I2C Master for ToF/FDC (Simplified)

```verilog
module simple_i2c_master (
    input wire clk,              // System clock
    input wire rst_n,
    input wire start,            // Start transaction
    input wire [6:0] dev_addr,   // I2C device address
    input wire [7:0] reg_addr,   // Register to read
    output reg [15:0] data_out,  // 16-bit read data
    output reg busy,
    output reg scl,
    inout wire sda
);

    reg sda_out;
    reg sda_oe;  // Output enable
    
    assign sda = sda_oe ? sda_out : 1'bz;
    
    localparam [3:0]
        IDLE = 4'h0,
        START_COND = 4'h1,
        SEND_ADDR = 4'h2,
        ACK1 = 4'h3,
        SEND_REG = 4'h4,
        ACK2 = 4'h5,
        RESTART = 4'h6,
        SEND_ADDR_RD = 4'h7,
        ACK3 = 4'h8,
        READ_HIGH = 4'h9,
        ACK4 = 4'hA,
        READ_LOW = 4'hB,
        NACK = 4'hC,
        STOP_COND = 4'hD;
    
    reg [3:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    
    // I2C clock generator (400 kHz from 50 MHz)
    reg [6:0] clk_div;
    wire i2c_clk_en = (clk_div == 7'd124);
    
    always @(posedge clk) begin
        if (clk_div == 7'd124)
            clk_div <= 7'd0;
        else
            clk_div <= clk_div + 1'b1;
    end
    
    // I2C state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scl <= 1'b1;
            sda_out <= 1'b1;
            sda_oe <= 1'b0;
            busy <= 1'b0;
        end else if (i2c_clk_en) begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= START_COND;
                        busy <= 1'b1;
                    end
                end
                
                START_COND: begin
                    sda_out <= 1'b0;  // Pull SDA low while SCL high
                    sda_oe <= 1'b1;
                    state <= SEND_ADDR;
                    shift_reg <= {dev_addr, 1'b0};  // Write bit
                    bit_cnt <= 4'd8;
                end
                
                // ... (implement full I2C protocol)
                
                STOP_COND: begin
                    scl <= 1'b1;
                    sda_out <= 1'b1;
                    sda_oe <= 1'b0;
                    busy <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
```

---

## Conclusion

**Current Implementation (Capacitive + SPI ADC)** is an excellent choice that balances:
- ✅ Authentic theremin feel
- ✅ Good performance (1-10 kHz update rate)
- ✅ Reasonable cost ($5-10)
- ✅ Already implemented in hardware

**For users who want alternatives:**
- **Simplest:** Ultrasonic sensors with GPIO ($2-4, easy to implement)
- **Best precision:** VL53L0X ToF sensors ($10-16, 1mm resolution)
- **Highest performance:** FDC2214 capacitive sensing ($5-8, 28-bit resolution)

The modular design allows easy swapping of theremin sensing methods by modifying only the `theremin_ctrl.v` module or implementing alternatives in parallel.

---

*Document Version: 1.0*  
*Last Updated: 2026-02-04*  
*Author: NativeChips AI Agent*

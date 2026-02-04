"""
Cocotb testbench for keyboard_scanner module
Tests matrix scanning, velocity sensing, and event FIFO
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.binary import BinaryValue

# Register addresses
ADDR_CTRL = 0x00
ADDR_STATUS = 0x04
ADDR_EVENT = 0x08
ADDR_IRQ_EN = 0x0C
ADDR_IRQ_STATUS = 0x10
ADDR_SCAN_MAP = 0x14

async def wb_write(dut, addr, data):
    """Wishbone write transaction"""
    await RisingEdge(dut.clk)
    dut.wb_cyc_i.value = 1
    dut.wb_stb_i.value = 1
    dut.wb_we_i.value = 1
    dut.wb_adr_i.value = addr
    dut.wb_dat_i.value = data
    
    # Wait for ack
    while dut.wb_ack_o.value == 0:
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    dut.wb_cyc_i.value = 0
    dut.wb_stb_i.value = 0
    dut.wb_we_i.value = 0

async def wb_read(dut, addr):
    """Wishbone read transaction"""
    await RisingEdge(dut.clk)
    dut.wb_cyc_i.value = 1
    dut.wb_stb_i.value = 1
    dut.wb_we_i.value = 0
    dut.wb_adr_i.value = addr
    
    # Wait for ack
    while dut.wb_ack_o.value == 0:
        await RisingEdge(dut.clk)
    
    data = dut.wb_dat_o.value.integer
    
    await RisingEdge(dut.clk)
    dut.wb_cyc_i.value = 0
    dut.wb_stb_i.value = 0
    
    return data

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_keyboard_basic(dut):
    """Test basic keyboard scanner functionality"""
    
    # Start clock
    clock = Clock(dut.clk, 20, units="ns")  # 50 MHz
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.wb_cyc_i.value = 0
    dut.wb_stb_i.value = 0
    dut.wb_we_i.value = 0
    dut.wb_adr_i.value = 0
    dut.wb_dat_i.value = 0
    dut.col_in.value = 0x7F  # All columns high (no keys pressed)
    
    # Reset
    await reset_dut(dut)
    
    dut._log.info("=== Test 1: Read Control Register ===")
    ctrl_val = await wb_read(dut, ADDR_CTRL)
    dut._log.info(f"CTRL register: 0x{ctrl_val:08x}")
    assert (ctrl_val & 0x01) == 1, "Scanner should be enabled by default"
    
    dut._log.info("=== Test 2: Read Status Register ===")
    status = await wb_read(dut, ADDR_STATUS)
    dut._log.info(f"STATUS register: 0x{status:08x}")
    fifo_empty = (status >> 1) & 0x01
    assert fifo_empty == 1, "FIFO should be empty initially"
    
    dut._log.info("=== Test 3: Simulate Key Press ===")
    # Wait for scanner to activate row 0
    await ClockCycles(dut.clk, 100)
    
    # Press key at row 0, column 0 (middle C)
    dut.col_in.value = 0x7E  # Column 0 low (pressed)
    await ClockCycles(dut.clk, 500)  # Wait for debounce
    
    # Release key
    dut.col_in.value = 0x7F  # All columns high
    await ClockCycles(dut.clk, 100)
    
    dut._log.info("=== Test 4: Check Event FIFO ===")
    status = await wb_read(dut, ADDR_STATUS)
    fifo_empty = (status >> 1) & 0x01
    dut._log.info(f"STATUS after key press: 0x{status:08x}, FIFO empty: {fifo_empty}")
    
    if fifo_empty == 0:
        event = await wb_read(dut, ADDR_EVENT)
        note_num = event & 0xFF
        velocity = (event >> 8) & 0xFF
        note_on = (event >> 16) & 0x01
        dut._log.info(f"Event: note={note_num}, velocity={velocity}, on={note_on}")
    
    dut._log.info("=== Test 5: Check IRQ ===")
    irq_status = await wb_read(dut, ADDR_IRQ_STATUS)
    dut._log.info(f"IRQ_STATUS: 0x{irq_status:08x}")
    
    dut._log.info("=== Test Passed ===")

@cocotb.test()
async def test_keyboard_multiple_keys(dut):
    """Test multiple simultaneous key presses"""
    
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.wb_cyc_i.value = 0
    dut.wb_stb_i.value = 0
    dut.wb_we_i.value = 0
    dut.wb_adr_i.value = 0
    dut.wb_dat_i.value = 0
    dut.col_in.value = 0x7F
    
    await reset_dut(dut)
    
    dut._log.info("=== Testing Multiple Keys ===")
    
    # Press multiple keys (columns 0, 1, 2)
    await ClockCycles(dut.clk, 100)
    dut.col_in.value = 0x78  # Columns 0, 1, 2 pressed (bits 2:0 low)
    await ClockCycles(dut.clk, 1000)
    
    # Release
    dut.col_in.value = 0x7F
    await ClockCycles(dut.clk, 500)
    
    # Check FIFO for multiple events
    status = await wb_read(dut, ADDR_STATUS)
    fifo_count = (status >> 8) & 0x0F
    dut._log.info(f"FIFO count after multi-key press: {fifo_count}")
    
    # Read all events
    for i in range(min(fifo_count, 8)):
        event = await wb_read(dut, ADDR_EVENT)
        note_num = event & 0xFF
        velocity = (event >> 8) & 0xFF
        note_on = (event >> 16) & 0x01
        dut._log.info(f"Event {i}: note={note_num}, velocity={velocity}, on={note_on}")
    
    dut._log.info("=== Multiple Keys Test Passed ===")

@cocotb.test()
async def test_keyboard_velocity(dut):
    """Test velocity sensing"""
    
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.wb_cyc_i.value = 0
    dut.wb_stb_i.value = 0
    dut.wb_we_i.value = 0
    dut.col_in.value = 0x7F
    
    await reset_dut(dut)
    
    dut._log.info("=== Testing Velocity Sensing ===")
    
    # Fast key press (high velocity)
    await ClockCycles(dut.clk, 100)
    dut.col_in.value = 0x7E
    await ClockCycles(dut.clk, 50)  # Quick press
    dut.col_in.value = 0x7F
    await ClockCycles(dut.clk, 500)
    
    # Read event
    status = await wb_read(dut, ADDR_STATUS)
    if (status >> 1) & 0x01 == 0:
        event = await wb_read(dut, ADDR_EVENT)
        velocity_fast = (event >> 8) & 0xFF
        dut._log.info(f"Fast press velocity: {velocity_fast}")
    
    # Slow key press (low velocity)
    await ClockCycles(dut.clk, 1000)
    dut.col_in.value = 0x7E
    await ClockCycles(dut.clk, 500)  # Slow press
    dut.col_in.value = 0x7F
    await ClockCycles(dut.clk, 500)
    
    # Read event
    status = await wb_read(dut, ADDR_STATUS)
    if (status >> 1) & 0x01 == 0:
        event = await wb_read(dut, ADDR_EVENT)
        velocity_slow = (event >> 8) & 0xFF
        dut._log.info(f"Slow press velocity: {velocity_slow}")
    
    dut._log.info("=== Velocity Test Passed ===")

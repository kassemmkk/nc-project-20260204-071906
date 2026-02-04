# Cocotb Makefile for keyboard_scanner test

TOPLEVEL_LANG = verilog
SIM = icarus

VERILOG_SOURCES = $(PWD)/../../../rtl/keyboard_scanner.v

TOPLEVEL = keyboard_scanner

MODULE = test_keyboard

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf __pycache__ sim_build results.xml *.vcd

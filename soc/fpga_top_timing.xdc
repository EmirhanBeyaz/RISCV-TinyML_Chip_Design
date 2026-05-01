# Board-independent timing constraints for early Vivado smoke runs.
#
# This file intentionally does not assign PACKAGE_PIN locations. Add a separate
# board-specific XDC for real FPGA programming.

create_clock -name sys_clk -period 10.000 [get_ports clk_i]

set_false_path -from [get_ports rst_ni]

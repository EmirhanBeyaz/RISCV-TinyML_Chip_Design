# Board-independent timing constraints for early Vivado smoke runs.
#
# This file intentionally does not assign PACKAGE_PIN locations. Add a separate
# board-specific XDC for real FPGA programming.

create_clock -name sys_clk -period 20.000 [get_ports clk_i]

set_false_path -from [get_ports rst_ni]

# These top-level pins are asynchronous or board-dependent in the smoke design.
# A real board XDC should replace these with pin, IO-standard, and IO-delay
# constraints for hardware sign-off.
set_false_path -from [get_ports {uart0_rx_i uart1_rx_i sw_i[*] i2c_scl_io i2c_sda_io qspi_dq_io[*]}]

set_false_path -to [get_ports {uart0_tx_o uart1_tx_o led_o[*] i2c_scl_io i2c_sda_io qspi_cs_n_o qspi_sck_o qspi_dq_io[*]}]

# Arty A7-100 Rev. D/E constraints for fpga_top_arty_a7.
# Pin choices are derived from Arty-A7-100-Master.xdc.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]
create_clock -name clk_100mhz -period 10.000 [get_ports { CLK100MHZ }]
create_generated_clock -name sys_clk -source [get_ports { CLK100MHZ }] -divide_by 2 [get_pins clk_50_q_reg/Q]

set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]

set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]
set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]
set_property -dict { PACKAGE_PIN B9 IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]
set_property -dict { PACKAGE_PIN B8 IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]

set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN G6  IOSTANDARD LVCMOS33 } [get_ports { led0_r }]
set_property -dict { PACKAGE_PIN G3  IOSTANDARD LVCMOS33 } [get_ports { led1_r }]
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports { led2_r }]
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { led3_r }]

set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { uart_rxd_out }]
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports { uart_txd_in }]

set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { ja0_i }]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { ja1_o }]

set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ck_scl }]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { ck_sda }]

set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[0] }]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[1] }]
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[2] }]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[3] }]

set_false_path -from [get_ports { btn[*] sw[*] uart_rxd_out ja0_i ck_sda qspi_dq[*] }]
set_false_path -to [get_ports { led[*] led0_r led1_r led2_r led3_r uart_txd_in ja1_o ck_scl ck_sda qspi_cs qspi_dq[*] }]

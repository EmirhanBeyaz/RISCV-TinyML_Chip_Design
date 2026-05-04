open_checkpoint soc/build/vivado_power/post_route.dcp
current_instance fpga_top_i/soc_i
read_saif soc/build/vivado_power/activity.saif -strip_path tb_cv32e40p_axi_soc_real/dut -verbose
current_instance
report_power -file soc/build/vivado_power/reports/power_test.rpt
exit 0

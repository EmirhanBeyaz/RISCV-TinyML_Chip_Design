open_checkpoint soc/build/vivado_power/post_route.dcp
set fh [open "nets_check.log" w]
puts $fh "NETS CHECK:"
puts $fh [get_nets -quiet fpga_top_i/soc_i/clk_i]
puts $fh [get_nets -quiet fpga_top_i/soc_i/rst_ni]
puts $fh [get_nets -quiet fpga_top_i/soc_i/fetch_enable_i]
puts $fh "Clock nets:"
puts $fh [get_nets -quiet -hierarchical -filter {NAME =~ fpga_top_i/soc_i/*clk*}]
close $fh
exit 0

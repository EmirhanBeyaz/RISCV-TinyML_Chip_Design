set out_dir soc/build/vivado_power_arty
set report_dir soc/build/vivado_power_arty/reports
set saif_file soc/build/vivado_power/activity_patched_v2.saif

file mkdir $out_dir
file mkdir $report_dir

create_project vivado_arty_proj $out_dir -part xc7a100tcsg324-1 -force
set target_top fpga_top_arty_a7
source soc/vivado_gui_add_sources.tcl

# We MUST use flatten_hierarchy none to prevent Vivado from optimizing away the hierarchy
# boundary of fpga_top_i/soc_i, which causes net name mismatch with SAIF!
synth_design -top fpga_top_arty_a7 -part xc7a100tcsg324-1 -flatten_hierarchy none
write_checkpoint -force [file join $out_dir post_synth.dcp]

opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $out_dir post_route.dcp]

puts "Reading SAIF..."
read_saif $saif_file -verbose

proc set_activity_safe {sp tr objects} {
  if {[llength $objects] > 0} {
    set_switching_activity -static_probability $sp -toggle_rate $tr $objects
  }
}
set_activity_safe 0.0 0.0 [get_ports -quiet {btn[0]}]
set_activity_safe 0.0 0.0 [get_ports -quiet {btn[1] btn[2] btn[3]}]
set_activity_safe 0.5 0.0 [get_ports -quiet {sw[0] sw[1] sw[2] sw[3]}]
set_activity_safe 0.9 0.46 [get_ports -quiet {uart_rxd_out}]
set_activity_safe 0.9 0.46 [get_ports -quiet {ja0_i}]
set_activity_safe 0.99 0.1 [get_ports -quiet {ck_sda}]
set_activity_safe 0.5 10.0 [get_ports -quiet {qspi_dq[0] qspi_dq[1] qspi_dq[2] qspi_dq[3]}]

report_power -file [file join $report_dir power_with_saif.rpt]
exit 0

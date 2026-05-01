if {$argc < 1} {
  puts "Usage: vivado -mode batch -source soc/vivado_impl.tcl -tclargs <part> ?nomodel|model? ?top?"
  puts "Example:"
  puts "  vivado -mode batch -source soc/vivado_impl.tcl -tclargs xc7a100tcsg324-1"
  exit 1
}

set part [lindex $argv 0]

set ai_model_mode "nomodel"
if {$argc >= 2} {
  set ai_model_mode [string tolower [lindex $argv 1]]
}

if {$ai_model_mode ni {"nomodel" "model"}} {
  puts "Unsupported AI model mode '$ai_model_mode'. Use 'nomodel' or 'model'."
  exit 1
}

set use_ai_model_pkg [expr {$ai_model_mode eq "model"}]

set target_top "fpga_top_arty_a7"
if {$argc >= 3} {
  set target_top [lindex $argv 2]
}

proc set_power_activity_if_present {static_probability toggle_rate objects} {
  if {[llength $objects] > 0} {
    set_switching_activity -static_probability $static_probability -toggle_rate $toggle_rate $objects
  }
}

proc apply_idle_power_activity {target_top} {
  set qspi_boot_hold_nets [get_nets -hierarchical -quiet -filter {NAME =~ *qspi_init_i/init_done_o_reg_0*}]
  if {[llength $qspi_boot_hold_nets] > 0} {
    puts "Power activity: marking QSPI boot-hold reset net deasserted in steady state."
    set_power_activity_if_present 0.0 0.0 $qspi_boot_hold_nets
  }

  if {$target_top eq "fpga_top_arty_a7"} {
    set_power_activity_if_present 0.0 0.0 [get_ports -quiet {btn[0]}]
    set_power_activity_if_present 0.0 0.0 [get_ports -quiet {btn[1] btn[2] btn[3]}]
    set_power_activity_if_present 0.5 0.0 [get_ports -quiet {sw[0] sw[1] sw[2] sw[3]}]
    set_power_activity_if_present 1.0 0.0 [get_ports -quiet {uart_rxd_out ck_sda}]
    set_power_activity_if_present 0.0 0.0 [get_ports -quiet {ja0_i}]
  }
}

set script_dir [file normalize [file dirname [info script]]]
set out_dir    [file normalize [file join $script_dir build vivado_impl "${target_top}_${part}_${ai_model_mode}"]]
set report_dir [file join $out_dir reports]

file mkdir $out_dir
file mkdir $report_dir

puts "Vivado implementation"
puts "Target part       : $part"
puts "Top module        : $target_top"
puts "AI model package  : $ai_model_mode"
puts "Output directory  : $out_dir"

create_project vivado_soc_impl $out_dir -part $part -force
source [file join $script_dir vivado_gui_add_sources.tcl]

synth_design -top $target_top -part $part
write_checkpoint -force [file join $out_dir post_synth.dcp]
report_utilization -hierarchical -file [file join $report_dir utilization_synth.rpt]
report_timing_summary -file [file join $report_dir timing_synth.rpt]

opt_design
place_design
phys_opt_design
route_design

write_checkpoint -force [file join $out_dir post_route.dcp]
report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_timing -delay_type max -sort_by group -max_paths 20 -file [file join $report_dir setup_paths.rpt]
report_timing -delay_type min -sort_by group -max_paths 20 -file [file join $report_dir hold_paths.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization_route.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_drc -file [file join $report_dir drc.rpt]
apply_idle_power_activity $target_top
report_power -file [file join $report_dir power.rpt]
report_power -advisory -file [file join $report_dir power_advisory.rpt]

puts "Implementation artifacts written under: $out_dir"
exit 0

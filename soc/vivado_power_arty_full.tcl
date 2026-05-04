# vivado_power_arty_full.tcl — Full implementation + XSim SAIF + annotated power report for Arty A7
#
# Usage:
#   vivado -mode batch -source soc/vivado_power_arty_full.tcl -tclargs xc7a100tcsg324-1

if {$argc < 1} {
  puts "Usage: vivado -mode batch -source soc/vivado_power_arty_full.tcl -tclargs <part>"
  exit 1
}

set part [lindex $argv 0]
set script_dir [file normalize [file dirname [info script]]]
set out_dir    [file normalize [file join $script_dir build vivado_power_arty]]
set report_dir [file join $out_dir reports]
set saif_file  [file join $out_dir activity_arty.saif]

file mkdir $out_dir
file mkdir $report_dir

puts "=============================================="
puts " Vivado Power Analysis with SAIF Annotation"
puts " Target: fpga_top_arty_a7 (High Confidence)"
puts "=============================================="

# PHASE 1: Implementation
create_project vivado_arty_proj $out_dir -part $part -force
set target_top fpga_top_arty_a7
source [file join $script_dir vivado_gui_add_sources.tcl]

synth_design -top fpga_top_arty_a7 -part $part -flatten_hierarchy none
write_checkpoint -force [file join $out_dir post_synth.dcp]

opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $out_dir post_route.dcp]

# PHASE 2: XSim SAIF Generation
set sim_tb [file join $script_dir tb_fpga_top_arty_a7.sv]
add_files -fileset sim_1 -norecurse $sim_tb
set_property top tb_fpga_top_arty_a7 [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {20us} -objects [get_filesets sim_1]

update_compile_order -fileset sim_1
launch_simulation

open_saif $saif_file
log_saif [get_objects -r /tb_fpga_top_arty_a7/dut/*]
run 20us
close_saif
close_sim

# PHASE 3: SAIF Annotation + Annotated Power Report
open_checkpoint [file join $out_dir post_route.dcp]

puts "Reading SAIF..."
read_saif $saif_file -strip_path tb_fpga_top_arty_a7/dut -verbose

# Apply static toggle rates to I/O that may not be captured or are constant
proc set_activity_safe {sp tr objects} {
  if {[llength $objects] > 0} {
    set_switching_activity -static_probability $sp -toggle_rate $tr $objects
  }
}

set_activity_safe 0.0 0.0 [get_ports -quiet {btn[0] btn[1] btn[2] btn[3]}]
set_activity_safe 0.5 0.0 [get_ports -quiet {sw[0] sw[1] sw[2] sw[3]}]
set_activity_safe 0.9 0.46 [get_ports -quiet {uart_rxd_out}]
set_activity_safe 0.9 0.46 [get_ports -quiet {ja0_i}]
set_activity_safe 0.99 0.1 [get_ports -quiet {ck_sda}]
set_activity_safe 0.5 10.0 [get_ports -quiet {qspi_dq[0] qspi_dq[1] qspi_dq[2] qspi_dq[3]}]

report_power -file [file join $report_dir power_with_saif.rpt]
report_power -advisory -file [file join $report_dir power_advisory.rpt]
report_power -hierarchical_depth 5 -file [file join $report_dir power_hierarchy.rpt]

puts "\n=============================================="
puts " DONE — All reports under: $report_dir"
puts "=============================================="
exit 0

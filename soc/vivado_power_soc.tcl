# vivado_power_soc.tcl — Full implementation + XSim SAIF + annotated power report for SoC
#
# Usage:
#   vivado -mode batch -source soc/vivado_power_soc.tcl -tclargs xc7a100tcsg324-1

if {$argc < 1} {
  puts "Usage: vivado -mode batch -source soc/vivado_power_soc.tcl -tclargs <part>"
  exit 1
}

set part [lindex $argv 0]
set script_dir [file normalize [file dirname [info script]]]
set out_dir    [file normalize [file join $script_dir build vivado_power_soc]]
set report_dir [file join $out_dir reports]
set saif_file  [file join $out_dir activity.saif]

file mkdir $out_dir
file mkdir $report_dir

puts "=============================================="
puts " Vivado Power Analysis with SAIF Annotation"
puts " Target: cv32e40p_axi_soc (High Confidence)"
puts "=============================================="

# PHASE 1: Implementation
create_project vivado_power_proj $out_dir -part $part -force
set target_top cv32e40p_axi_soc
source [file join $script_dir vivado_gui_add_sources.tcl]

# Add a basic clock constraint for the out-of-context SoC
set xdc_file [file join $out_dir ooc_clock.xdc]
set fh [open $xdc_file w]
puts $fh "create_clock -name clk_i -period 20.000 \[get_ports clk_i\]"
close $fh
add_files -fileset constrs_1 -norecurse $xdc_file
set_property used_in_synthesis false [get_files $xdc_file]
set_property used_in_implementation true [get_files $xdc_file]

# Synthesize as out-of-context since it's an inner block without pin maps
synth_design -top cv32e40p_axi_soc -part $part -mode out_of_context
write_checkpoint -force [file join $out_dir post_synth.dcp]

opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $out_dir post_route.dcp]

# PHASE 2: XSim SAIF Generation
set sim_tb [file join $script_dir tb_cv32e40p_axi_soc_real.sv]
add_files -fileset sim_1 -norecurse $sim_tb
set_property top tb_cv32e40p_axi_soc_real [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {20us} -objects [get_filesets sim_1]

update_compile_order -fileset sim_1
launch_simulation

open_saif $saif_file
log_saif [get_objects -r /tb_cv32e40p_axi_soc_real/dut/*]
run 20us
close_saif
close_sim

# PHASE 3: SAIF Annotation + Annotated Power Report
open_checkpoint [file join $out_dir post_route.dcp]

puts "Reading SAIF..."
read_saif $saif_file -strip_path tb_cv32e40p_axi_soc_real/dut -verbose

report_power -file [file join $report_dir power_with_saif.rpt]
report_power -advisory -file [file join $report_dir power_advisory.rpt]
report_power -hierarchical_depth 5 -file [file join $report_dir power_hierarchy.rpt]

puts "\n=============================================="
puts " DONE — All reports under: $report_dir"
puts "=============================================="
exit 0

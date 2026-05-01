if {$argc < 1} {
  puts "Usage: vivado -mode batch -source soc/vivado_impl.tcl -tclargs <part> ?nomodel|model?"
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

set script_dir [file normalize [file dirname [info script]]]
set out_dir    [file normalize [file join $script_dir build vivado_impl "fpga_top_${part}_${ai_model_mode}"]]
set report_dir [file join $out_dir reports]

file mkdir $out_dir
file mkdir $report_dir

puts "Vivado implementation"
puts "Target part       : $part"
puts "AI model package  : $ai_model_mode"
puts "Output directory  : $out_dir"

create_project vivado_soc_impl $out_dir -part $part -force
source [file join $script_dir vivado_gui_add_sources.tcl]

synth_design -top fpga_top -part $part
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

puts "Implementation artifacts written under: $out_dir"
exit 0
